#!/usr/bin/ruby
#--
# Copyright (c) 2014-2015, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
#
# Find all items in the source collection (or all collections) which have
# bitstreams and are not yet mapped to the destination collection, then
# create a BMET CSV file which will map them to the destination collection.
#
# ALGORITHM
# - Find all items in the DSpace source collection (or all collections) which
#   have bitstreams and are not yet mapped to the destination collection
# - Create a DSpace Batch Metadata Editing Tool (BMET) CSV file which will
#   map them to the destination collection
# - Send report via email
#
#++
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

require 'dspace_utils'
require 'resources4bmet_csv'
require 'object_extra'
require 'rubygems'
require 'pg'
require 'pg_extra'
require 'dbc'

##############################################################################
# A class for representing DSpace database items which are to be mapped
# from the source collection to the destination collection.
#
# This program will produce a CSV file suitable for updating the item
# mapping using the DSpace Batch Metadata Editing Tool (BMET).
##############################################################################
class Items4Mapping
  include DbConnection
  include DSpaceUtils

  # true = source items from all collections (ie. ignore SOURCE_COLLECTION_HANDLE);
  # false = source items from the collection specified by SOURCE_COLLECTION_HANDLE
  IS_SOURCE_ALL_COLLECTIONS = false				# Customise
  SOURCE_COLLECTION_HANDLE = '123456789/6225'			# Customise
  DEST_COLLECTION_HANDLE   = '123456789/6226'			# Customise

  HANDLE_URL_LEFT_STRING = 'http://dspace.example.com/jsp/handle/'	# Customise

  WILL_SHOW_RMID = true

  MAX_ITEMS_TO_PROCESS = 100			# DSpace 3 manual recommends 1000 BMET records max
  MAX_ITEMS_WARN_MSG = <<-MSG_WARN1.gsub(/^\t*/, '')
	**WARNING**
	  The number of new full-text items has reached the mapping run-limit of #{MAX_ITEMS_TO_PROCESS}.
	  It is recommended that you check that this high-number of items is expected.
  MSG_WARN1

  ############################################################################
  # Constructor for this object
  ############################################################################
  def initialize
    @items = []
  end

  ############################################################################
  # Extract and return items from the database. These items:
  # - have not been withdrawn;
  # - have been published (in_archive = 't' and owning_collection is not null
  #   and exists in handle table);
  # - are in the source collection (ie. SOURCE_COLLECTION_HANDLE) or all
  #   collections;
  # - are not in the destination collection (ie. DEST_COLLECTION_HANDLE);
  # - have (non-licence) bitstreams attached (ie. bundle is 'ORIGINAL')
  #   which have not been deleted and which have at least one bitstream
  #   which is not under embargo
  #
  # Also, these items might be owned-by or mapped-to a collection which is
  # neither SOURCE_COLLECTION_HANDLE nor DEST_COLLECTION_HANDLE.
  ############################################################################
  def get_items_from_db
    sql_source_clause = if IS_SOURCE_ALL_COLLECTIONS
      <<-SQL_GET_ITEMS_FROM_ALL_COLLECTIONS.gsub(/^\t*/, '')
	    item_id in (select item_id from collection2item)
      SQL_GET_ITEMS_FROM_ALL_COLLECTIONS

    else
      <<-SQL_GET_ITEMS_FROM_SOURCE_COLLECTION.gsub(/^\t*/, '')
	    item_id in
	    (select item_id from collection2item where collection_id in
	      (select resource_id from handle where resource_type_id=3 and handle='#{SOURCE_COLLECTION_HANDLE}')
	    )
      SQL_GET_ITEMS_FROM_SOURCE_COLLECTION
    end

    sql = <<-SQL_GET_ITEMS.gsub(/^\t*/, '')
	select
	  i.item_id,
	  (select handle from handle where resource_type_id=2 and resource_id=i.item_id) item_hdl,
	  (select handle from handle where resource_type_id=3 and resource_id=i.owning_collection) owning_collection_hdl,

	  array_to_string(array(
	    select handle from handle where resource_type_id=3 and resource_id in
	      (select collection_id from collection2item where item_id=i.item_id)
	  ), '||') all_collection_hdls,

	  array_to_string(array(
	    select text_value from metadatavalue where item_id=i.item_id and metadata_field_id =
	      (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid')
	  ), '||') dc_id_rmids,

	  array_to_string(array(
	    select text_value from metadatavalue where item_id=i.item_id and metadata_field_id =
	      (select metadata_field_id from metadatafieldregistry where element='title' and qualifier is null)
	  ), '||') dc_titles
	from
	(
	  select distinct item_id, owning_collection
	  from item
	  where
	    withdrawn = 'f' and

	    in_archive = 't' and
            owning_collection is not null and
            exists (select resource_id from handle h where h.resource_type_id=2 and h.resource_id=item_id) and

            #{sql_source_clause} and

	    item_id not in
	    (select item_id from collection2item where collection_id in
	      (select resource_id from handle where resource_type_id=3 and handle='#{DEST_COLLECTION_HANDLE}')
	    ) and

	    item_id in
	    (select item_id from item2bundle where bundle_id in
	      (select bundle_id from bundle where name='ORIGINAL' and bundle_id in
	        (select bundle_id from bundle2bitstream where bitstream_id in
	          (select bitstream_id from bitstream where deleted<>'t' and bitstream_id not in
                    (select resource_id from resourcepolicy where resource_type_id=0 and start_date > 'now')
                  )
	        )
	      )
	    )
	) i
	order by i.item_id;
    SQL_GET_ITEMS

    @items = []
    PG::Connection.connect2(DB_CONNECT_INFO){|conn|
      conn.exec(sql){|result|
        result.each{|row|
          return if @items.length >= MAX_ITEMS_TO_PROCESS

          @items << {
            # Required for BMET CSV file
            :item_id			=> row['item_id'],
            :owning_collection_hdl	=> row['owning_collection_hdl'],
            :all_collection_hdls	=> row['all_collection_hdls'],

            # Only required for reporting
            :item_hdl			=> row['item_hdl'],
            :dc_id_rmids		=> row['dc_id_rmids'],
            :dc_titles			=> row['dc_titles'],
          } 

        }
      }
    }
  end

  ############################################################################
  # Create a BMET CSV string for the items to be mapped (while preserving
  # the owning collection)
  ############################################################################
  def to_s_bmet_csv
    return '' if @items.empty?

    lines = []		# An array of CSV lines
    lines << "id,collection"
    @items.each_with_index{|item, i|
      # First collection must be owner; let second collection be mapped dest
      collection_handles = [ item[:owning_collection_hdl], DEST_COLLECTION_HANDLE ]

      # Append other mapped collections
      all_collection_handles = item[:all_collection_hdls].split(VALUE_DELIMITER).sort
      extra_handles = all_collection_handles - collection_handles
      collection_handles += extra_handles

      lines << "#{item[:item_id]},#{collection_handles.join(VALUE_DELIMITER)}"
    }
    lines.join(NEWLINE) + NEWLINE
  end

  ############################################################################
  # Create a report for these items
  ############################################################################
  def to_s_report
    res = Resources4BmetCsv.new
    preamble = <<-REPORT_PREAMBLE.gsub(/^\t*/, '')
	#{@items.length >= MAX_ITEMS_TO_PROCESS ? MAX_ITEMS_WARN_MSG : ''}
	Program:                        #{File.basename($0)}
	Source collection handle:       #{IS_SOURCE_ALL_COLLECTIONS ? 'All collections' : self.class.handle_to_url(SOURCE_COLLECTION_HANDLE)}
	Source collection name:         #{IS_SOURCE_ALL_COLLECTIONS ? 'All collections' : sres.lookup_collection_name(SOURCE_COLLECTION_HANDLE)}

	Destination collection handle:  #{self.class.handle_to_url(DEST_COLLECTION_HANDLE)}
	Destination collection name:    #{res.lookup_collection_name(DEST_COLLECTION_HANDLE)}
	Number of new items to map to destination:  #{@items.length}

    REPORT_PREAMBLE

    lines = []
    unless @items.empty?
      lines << "ITEMS BEING MAPPED:"
      lines << ""

      hdl_width = [
        "#{self.class.handle_to_url(@items.first[:item_hdl])};".length,
        "ItemHandle;".length
      ].max

      if WILL_SHOW_RMID
        lines << sprintf(" %s) %-11s %-#{hdl_width}s %-5s %s", "#","ItemRMID;","ItemHandle;","Id;","ItemTitle")
        @items.each_with_index{|item, i|
          lines << " #{i+1}) #{item[:dc_id_rmids]}; #{self.class.handle_to_url(item[:item_hdl])}; #{item[:item_id]}; #{item[:dc_titles]}"
        }

      else
        lines << sprintf(" %s) %-#{hdl_width}s %-5s %s", "#","ItemHandle;","Id;","ItemTitle")
        @items.each_with_index{|item, i|
          lines << " #{i+1}) #{self.class.handle_to_url(item[:item_hdl])}; #{item[:item_id]}; #{item[:dc_titles]}"
        }
      end
    end

    preamble + lines.join(NEWLINE) + NEWLINE
  end

  ############################################################################
  # Convert a handle string into a URL string
  ############################################################################
  def self.handle_to_url(handle)
    "#{HANDLE_URL_LEFT_STRING}#{handle}"
  end

  ############################################################################
  # The main method for this class
  ############################################################################
  def self.main
    STDERR.puts "\nCreating a DSpace BMET CSV file for mapping"
    STDERR.puts   "-------------------------------------------"

    items = Items4Mapping.new
    items.get_items_from_db
    puts items.to_s_bmet_csv
    STDERR.puts items.to_s_report
  end

end

##############################################################################
# Main
##############################################################################
Items4Mapping.main
exit 0

