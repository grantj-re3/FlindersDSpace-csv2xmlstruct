#!/usr/bin/ruby
#--
# Copyright (c) 2018, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
#
# Find all items in the source collection (or all collections) which have
# bitstreams. Find an report any bitstream filenames where the filename
# does *not* start with the RMID. Eg. For RMID 2000111222, the following
# filenames will *not* be reported:
# - 2000111222_ABC.DOCX
# - 2000111222.pdf
# and the following filenames *will* be reported:
# - 2000111229_ABC.DOCX
# - 2000111229.pdf
# - 200011122.pdf
# - x2000111222.pdf
#
# ALGORITHM
# - Find all items in the DSpace source collection (or all collections) which
#   have bitstreams.
# - Find all bitstream filenames which do not start with the RMID. Note that
#   an item may have more than one bitstream.
# - All report info (and errors) should be sent to STDERR.
# - CSV spreadsheet should be sent to STDOUT.
#
#++
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

require 'pp'
require 'dspace_utils'
require 'resources4bmet_csv'
require 'object_extra'
require 'rubygems'
require 'pg'
require 'pg_extra'
require 'dbc'

##############################################################################
# A class for representing DSpace database items which are to be checked.
#
# This program will produce a CSV file listing bitstream filenames which
# do not comply with naming rules.
##############################################################################
class Items4Checking
  include DSpacePgUtils

  # true = source items from all collections (ie. ignore SOURCE_COLLECTION_HANDLE);
  # false = source items from the collection specified by SOURCE_COLLECTION_HANDLE
  IS_SOURCE_ALL_COLLECTIONS = false				# Customise
  SOURCE_COLLECTION_HANDLE = '123456789/34234'			# Customise

  # Append:
  #   handle-prefix + "/" + handle-suffix
  # to this string to produce a valid URL.
  HANDLE_URL_LEFT_STRING = 'https://dspace.example.com/xmlui/handle/'	# Customise

  MAX_ITEMS_TO_PROCESS = 99999					# Reduce for testing
  MAX_ITEMS_WARN_MSG = <<-MSG_WARN1.gsub(/^\t*/, '')
	**WARNING**
	  The number of items has reached the processing-limit of #{MAX_ITEMS_TO_PROCESS}.
	  It is recommended that you check that this high-number of items is expected.
  MSG_WARN1

  ############################################################################
  # Constructor for this object
  ############################################################################
  def initialize
    @items = []
    @bad_filenames = []
    @num_filenames = 0
  end

  ############################################################################
  # Extract and return items from the database. These items:
  # - have not been withdrawn;
  # - have been published (in_archive = 't' and owning_collection is not null
  #   and exists in handle table);
  # - are in the source collection (ie. SOURCE_COLLECTION_HANDLE) or all
  #   collections;
  # - have (non-licence) bitstreams attached (ie. bundle is 'ORIGINAL')
  #   which have not been deleted and which have at least one bitstream
  #   which is not under embargo
  #
  # Also, these items might be owned-by or mapped-to a collection which is
  # not the SOURCE_COLLECTION_HANDLE.
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
	      (select resource_id from handle where resource_type_id=#{RESOURCE_TYPE_IDS[:collection]} and handle='#{SOURCE_COLLECTION_HANDLE}')
	    )
      SQL_GET_ITEMS_FROM_SOURCE_COLLECTION
    end

    sql_dc_field_select_clause = if Resources4BmetCsv.are_object_names_in_metadatavalue
      "select text_value from metadatavalue where resource_type_id=#{RESOURCE_TYPE_IDS[:item]} and resource_id=i.item_id and metadata_field_id in"
    else
      "select text_value from metadatavalue where item_id=i.item_id and metadata_field_id ="
    end

    sql_bundle_id_in_clause = if Resources4BmetCsv.are_object_names_in_metadatavalue
      <<-SQL_ITEM_ID_IN1.gsub(/^\t*/, '')
              (select resource_id from metadatavalue where text_value='ORIGINAL' and resource_type_id=#{RESOURCE_TYPE_IDS[:bundle]} and metadata_field_id in
                (select metadata_field_id from metadatafieldregistry where element='title' and qualifier is null)
              )
      SQL_ITEM_ID_IN1

    else
      <<-SQL_ITEM_ID_IN2.gsub(/^\t*/, '')
	      (select bundle_id from bundle where name='ORIGINAL' and bundle_id in
	      )
      SQL_ITEM_ID_IN2

    end

    sql = <<-SQL_GET_ITEMS.gsub(/^\t*/, '')
	select
	  i.item_id,
	  i.last_modified,
	  (select handle from handle where resource_type_id=#{RESOURCE_TYPE_IDS[:item]} and resource_id=i.item_id) item_hdl,
	  (select handle from handle where resource_type_id=#{RESOURCE_TYPE_IDS[:collection]} and resource_id=i.owning_collection) owning_collection_hdl,

	  array_to_string(array(
	    select handle from handle where resource_type_id=#{RESOURCE_TYPE_IDS[:collection]} and resource_id in
	      (select collection_id from collection2item where item_id=i.item_id)
	  ), '||') all_collection_hdls,

	  array_to_string(array(
            #{sql_dc_field_select_clause}
	      (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid')
	  ), '||') dc_id_rmids,

	  array_to_string(array(
	    select text_value from metadatavalue where resource_type_id=#{RESOURCE_TYPE_IDS[:bitstream]} and metadata_field_id in
	      (select metadata_field_id from metadatafieldregistry where element='title' and qualifier is null)
	    and resource_id in (
	      select bitstream_id from bundle2bitstream where bundle_id in (
	        select bundle_id from bundle where bundle_id in (select bundle_id from item2bundle where item_id=i.item_id) and bundle_id in (
	              select resource_id from metadatavalue where text_value='ORIGINAL' and resource_type_id=#{RESOURCE_TYPE_IDS[:bundle]} and metadata_field_id in
	            (select metadata_field_id from metadatafieldregistry where element='title' and qualifier is null)
	        )
	      )
	    )
	  ), '||') filenames

	from
	(
	  select distinct item_id, owning_collection, last_modified
	  from item
	  where
	    withdrawn = 'f' and

	    in_archive = 't' and
            owning_collection is not null and
            exists (select resource_id from handle h where h.resource_type_id=#{RESOURCE_TYPE_IDS[:item]} and h.resource_id=item_id) and

            #{sql_source_clause} and

	    item_id in
            (select item_id from item2bundle where bundle_id in
              #{sql_bundle_id_in_clause}
            and bundle_id in
              (select bundle_id from bundle2bitstream where bitstream_id in
                (select bitstream_id from bitstream where deleted<>'t' and bitstream_id not in
                  (select resource_id from resourcepolicy where resource_type_id=#{RESOURCE_TYPE_IDS[:bitstream]} and start_date > 'now')
                )
              )
            )
	) i
	order by i.item_id;
    SQL_GET_ITEMS

    @items = []
    @num_filenames = 0
    PG::Connection.connect2(DB_CONNECT_INFO){|conn|
      conn.exec(sql){|result|
        result.each{|row|
          return if @items.length >= MAX_ITEMS_TO_PROCESS

          item = {
            # Required
            :item_id			=> row['item_id'],
            :item_hdl			=> row['item_hdl'],
            :dc_id_rmids		=> row['dc_id_rmids'],
            :filenames			=> row['filenames'],
            :filename_list		=> row['filenames'].split(VALUE_DELIMITER),

            # Might be handy
            :last_modified		=> row['last_modified'],
            :owning_collection_hdl	=> row['owning_collection_hdl'],
            :all_collection_hdls	=> row['all_collection_hdls'],
          } 
          @num_filenames += item[:filename_list].length
          @items << item
        }
      }
    }
  end

  ############################################################################
  # Dump the contents of the instance variable given by the symbol
  # obj_sym to STDERR. Eg. If you call dump(:a), this method will
  # return the contents of @a.
  ############################################################################
  def dump(obj_sym)
    obj_name = "@#{obj_sym}"
    STDERR.puts "START-DUMP: #{obj_name}"
    STDERR.puts instance_variable_get(obj_name.to_sym).pretty_inspect
    STDERR.puts "END-DUMP: #{obj_name}"
  end

  ############################################################################
  # Append info to @bad_filenames list
  ############################################################################
  def append_to_bad_filenames(item, fname)
    @bad_filenames << {
      :item_id			=> item[:item_id],
      :item_hdl			=> item[:item_hdl],
      :dc_id_rmids		=> item[:dc_id_rmids],
      :filename			=> fname,
      :last_modified		=> item[:last_modified],
      # Replace "2018-01-25 03:01:32.811+10:30" with "2018-01-25"
      :last_modified_short	=> item[:last_modified].sub(/ .*$/, ""),
    }
  end

  ############################################################################
  # Find filenames which do *not* start with the RMID
  ############################################################################
  def get_bad_filenames
    @bad_filenames = []
    return if @items.empty?

    @items.each_with_index{|item, i|
      STDERR.puts "WARNING: More than one RMID for item:\n#{item.pretty_inspect}" unless item[:dc_id_rmids].split(VALUE_DELIMITER).length == 1

      item[:filename_list].each{|fname|
        rmid_len = item[:dc_id_rmids].length
        if fname.length < rmid_len
          append_to_bad_filenames(item, fname)
          next
        end
        if fname[0,rmid_len] != item[:dc_id_rmids]
          append_to_bad_filenames(item, fname)
        end
      }
    }
  end

  ############################################################################
  # Return an sprintf format-string with field-lengths which are suitable
  # for a fixed character-width report
  ############################################################################
  def report_format_string(hdr_list, obj_list)
    return "" if obj_list.empty?
    return "Report format-string error" unless hdr_list.length == 6
    hdl_width = [
      "#{self.class.handle_to_url(obj_list.first[:item_hdl])};".length,
      hdr_list[2].length
    ].max

    lmod_width = [
      "#{obj_list.first[:last_modified_short]};".length,
      hdr_list[4].length
    ].max

    "%4s) %-11s %-#{hdl_width}s %-7s %-#{lmod_width}s %s"
  end

  ############################################################################
  # Return a report (as a string) for bad filenames
  ############################################################################
  def to_s_report
    res = Resources4BmetCsv.new
    preamble = <<-REPORT_PREAMBLE.gsub(/^\t*/, '')
	#{@items.length >= MAX_ITEMS_TO_PROCESS ? MAX_ITEMS_WARN_MSG : ''}
	Program:                         #{File.basename($0)}
	Source collection handle:        #{IS_SOURCE_ALL_COLLECTIONS ? 'All collections' : self.class.handle_to_url(SOURCE_COLLECTION_HANDLE)}
	Source collection name:          #{IS_SOURCE_ALL_COLLECTIONS ? 'All collections' : res.lookup_collection_name(SOURCE_COLLECTION_HANDLE)}

	Number of items with bitstreams: #{@items.length}
	Number of filenames checked:     #{@num_filenames}
	Number of bad filenames:         #{@bad_filenames.length}

    REPORT_PREAMBLE

    lines = []
    obj_list = @bad_filenames
    unless obj_list.empty?
      lines << "BITSTREAMS WHERE FILENAME DOES NOT START WITH RMID:"
      lines << ""

      # Header line
      hdr_list = ["#","ItemRMID;","ItemHandle;","ItemId;","LastModified;","Filename;"]
      fmt_str = report_format_string(hdr_list, obj_list)
      lines << fmt_str % hdr_list

      # Detail lines
      obj_list.each_with_index{|item, i|
        lines << fmt_str % [i+1, item[:dc_id_rmids], self.class.handle_to_url(item[:item_hdl]),
          item[:item_id], item[:last_modified_short], item[:filename]]
      }

    end

    preamble + lines.join(NEWLINE) + NEWLINE
  end

  ############################################################################
  # Return a CSV file (as a string) for bad filenames
  ############################################################################
  def to_s_bad_filenames_csv
    obj_list = @bad_filenames
    return '' if obj_list.empty?

    lines = []
    unless obj_list.empty?
      # Header line
      hdr_list = ["ItemRMID","ItemHandle","ItemId","LastModified","Filename"]
      fmt_str = hdr_list.inject([]){|a,s| a << "\"%s\""}.join(",")
      lines << fmt_str % hdr_list

      # Detail lines
      obj_list.each_with_index{|item, i|
        lines << fmt_str % [item[:dc_id_rmids], self.class.handle_to_url(item[:item_hdl]),
          item[:item_id], item[:last_modified], item[:filename]]
      }
    end

    lines.join(NEWLINE)
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
    STDERR.puts "\nChecking bitstream filenames start with RMID"
    STDERR.puts   "--------------------------------------------"

    items = Items4Checking.new
    items.get_items_from_db
    #items.dump :items

    items.get_bad_filenames
    #items.dump :bad_filenames

    puts items.to_s_bad_filenames_csv
    STDERR.puts items.to_s_report
  end

end

##############################################################################
# Main
##############################################################################
Items4Checking.main
exit 0

