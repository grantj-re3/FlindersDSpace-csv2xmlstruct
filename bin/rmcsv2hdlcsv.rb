#!/usr/bin/ruby
# rmcsv2hdlcsv.rb
# 
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
# Convert RM-CSV file for a specified ERA reporting year with column names
# which are typically:
# - RMID,FOR4D_Owner,FOR4D_Others
# to a Handle-CSV file with column names which are typically:
# - Item_Hdl,Col_Owner_Hdl,Col_Others_Hdl
#
##############################################################################

# Add dirs to the library path
$: << File.expand_path(".", File.dirname(__FILE__))
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << File.expand_path("../lib/libext", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

require 'faster_csv'
require 'dspace_pg_utils'

##############################################################################
class RmCsv2HandleCsv
  include DSpacePgUtils

  # In the output-CSV, include input-CSV columns which are being translated
  WILL_INCLUDE_INPUT_COLUMNS = true

  # Input-CSV column names
  RmidItem = 'RMID'
  PrefixColOwner = 'FOR4D_Owner'
  PrefixColList = 'FOR4D_Others'

  # Output-CSV column names
  HdlItem = 'Item_Hdl'
  HdlColOwner = 'Col_Owner_Hdl'
  HdlColList = 'Col_Others_Hdl'

  # An array of CSV column name pairs where:
  # - the first column name is from the input-CSV file and represents the
  #   value to be translated
  # - the second column name is from the output-CSV file and represents
  #   the translated/transformed value
  COLUMN_TRANSLATIONS = [
    [RmidItem,		HdlItem],
    [PrefixColOwner,	HdlColOwner],
    [PrefixColList,	HdlColList],
  ]

  # Extract the input-CSV and output-CSV column names into separate arrays
  CSV_IN_COLUMNS  = COLUMN_TRANSLATIONS.inject([]){|a,(in_col,out_col)| a << in_col}
  CSV_OUT_COLUMNS = COLUMN_TRANSLATIONS.inject([]){|a,(in_col,out_col)| a << out_col}

  # FasterCSV options for reading CSV file
  FCSV_IN_OPTS = {
    :col_sep => ',',
    :headers => true,
  }
  # FasterCSV options for writing CSV to output
  FCSV_OUT_OPTS = {
    :col_sep => ',',
    :headers => true,
    :force_quotes => true,
  }

  attr_reader :in_file, :era_year_handle, :csv_out_headers, :csv_out_data

  ############################################################################
  # Create a new object from the specified CSV input file.
  def initialize(csv_in_filename, era_year_handle, rmid_from_era_year_handles_string)
    @in_file = csv_in_filename
    verify_in_file

    @db_conn = PG::Connection.connect(DB_CONNECT_INFO)	# Connect to the DB
    @era_year_handle = era_year_handle
    verify_era_year_handle

    @rmid_from_era_year_handles_string = rmid_from_era_year_handles_string
    if @rmid_from_era_year_handles_string == 'any'
      @rmid_from_era_year_handles = nil
      @rmid_from_era_year_handles_regex = nil
    else
      @rmid_from_era_year_handles = rmid_from_era_year_handles_string.split(',')
      @rmid_from_era_year_handles_regex = "^(#{@rmid_from_era_year_handles.join('|')})$"
    end
    verify_rmid_from_era_year_handles

    @csv_out_headers = nil
    @csv_out_data = nil
    @handles_by_prefix = {}		# Cache for collection-handles
    convert
    @db_conn.close if @db_conn
  end

  ############################################################################
  # Represent object as a string.
  def to_s
    @csv_out_data
  end

  private

  ############################################################################
  # Verify the RM-CSV input file
  def verify_in_file
    STDERR.puts "\nRM input-CSV filename:                    #{@in_file}"
    unless File.file?(@in_file) && File.readable?(@in_file)
      STDERR.puts "CSV file '#{@in_file}' is not found or is not readable."
      exit 6
    end

  end

  ############################################################################
  # Verify the ERA reporting-year handle
  def verify_era_year_handle
    STDERR.puts "\nTarget ERA reporting-year handle:         #{@era_year_handle}"
    sql = <<-SQL_ERA_YEAR_COMMUNITY_NAME.gsub(/^\t*/, '')
	select community_id,name from community where community_id = 
	  (select resource_id from handle where handle='#{@era_year_handle}' and resource_type_id=#{RESOURCE_TYPE_IDS[:community]})
    SQL_ERA_YEAR_COMMUNITY_NAME
    db_connect{|conn|
      conn.exec(sql){|result|
        if result.ntuples == 0
          STDERR.puts "Quitting: No community found when looking up ERA reporting-year handle: '#{@era_year_handle}'"
          exit 5
        else
          result.each{|row| STDERR.puts "Target ERA reporting-year community name: #{row['name']}" }
        end
      }
    }
  end

  ############################################################################
  # Verify the ERA reporting-year handles (from which RMIDs shall be selected)
  def verify_rmid_from_era_year_handles
    STDERR.puts "\nERA reporting-year handles for RMIDs:     #{@rmid_from_era_year_handles_string}"
    return if @rmid_from_era_year_handles_string == 'any'

    @rmid_from_era_year_handles.each{|hdl|
      sql = <<-SQL_RMID_ERA_YEAR_COMMUNITY_NAME.gsub(/^\t*/, '')
	select community_id,name from community where community_id = 
	  (select resource_id from handle where handle='#{hdl}' and resource_type_id=#{RESOURCE_TYPE_IDS[:community]})
      SQL_RMID_ERA_YEAR_COMMUNITY_NAME
      db_connect{|conn|
        conn.exec(sql){|result|
          if result.ntuples == 0
            STDERR.puts "Quitting: No community found when looking up ERA reporting-year handle (for RMIDs): '#{hdl}'"
            exit 5
          else
            result.each{|row| STDERR.puts "  Handle: #{hdl};  Community name: #{row['name']}" }
          end
        }
      }
    }
  end

  ############################################################################
  # Return the handle for the specified RMID. Quit unless the RMID maps
  # to exactly one handle and the handle is not null.
  # - If from == :anywhere, RMID can be selected from any item in the
  #   database
  # - If from == :era_year, RMID can only be selected from within the
  #   specified ERA year
  def get_handle_for_rmid(rmid)
    if @rmid_from_era_year_handles_regex == nil
      msg_append = "anywhere within database"
      sql = <<-SQL_HANDLE4RMID1.gsub(/^\t*/, '')
	select
	  item_id,
	  (select handle from handle where resource_id=mv.item_id and resource_type_id=#{RESOURCE_TYPE_IDS[:item]}) item_hdl,
	  text_value rmid
	from metadatavalue mv
	where
	  text_value='#{rmid}' and metadata_field_id=
	    (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid');
      SQL_HANDLE4RMID1
    else
      msg_append = "for ERA reporting-year with handles regex #{@rmid_from_era_year_handles_regex}"
      sql = <<-SQL_HANDLE4RMID2.gsub(/^\t*/, '')
	select
	  i.item_id,
	  (select handle from handle where resource_id=i.item_id and resource_type_id=#{RESOURCE_TYPE_IDS[:item]}) item_hdl,
	  mv.text_value rmid
	from
	(
	  select distinct item.item_id
	  from
	    item,
	    community2collection com2c,
	    collection2item c2i
	  where
	    com2c.community_id in
	      (select child_comm_id from community2community where parent_comm_id in
	        (select resource_id from handle where handle~'#{@rmid_from_era_year_handles_regex}' and resource_type_id=#{RESOURCE_TYPE_IDS[:community]})
	      )
	    and c2i.collection_id=com2c.collection_id
	    and c2i.item_id not in (select item_id from item where withdrawn=true)
	    and item.item_id = c2i.item_id
	) i, 
	(
	  select item_id, text_value
	  from metadatavalue
	  where
	    text_value='#{rmid}' and metadata_field_id=
	      (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid')
	) mv
	where
	  i.item_id = mv.item_id;
      SQL_HANDLE4RMID2
    end
    handle = nil
    db_connect{|conn|
      conn.exec(sql){|result|
        if result.ntuples == 1
          result.each{|row| handle = row['item_hdl']}
        elsif result.ntuples == 0
          STDERR.puts "Quitting: No item record found when looking up RMID #{rmid} #{msg_append}"
          exit 4
        else
          STDERR.puts "Quitting: More than one distinct item record found when looking up RMID #{rmid} #{msg_append}"
          exit 4
        end
      }
    }
    if handle
      handle
    else
      STDERR.puts "Quitting: No handle found for the item with RMID #{rmid} #{msg_append}"
      exit 4
    end
  end

  ############################################################################
  # Return the handle for the specified collection prefix. Quit unless the
  # collection prefix maps to exactly one handle and the handle is not null.
  def get_handle_for_collection_prefix(collection_prefix)
    # Retrieve handle from cache if it exists
    return @handles_by_prefix[collection_prefix] if @handles_by_prefix[collection_prefix]

    handle = nil
    sql = <<-SQL_HANDLE4COLLECTION_PREFIX.gsub(/^\t*/, '')
	select
	  c.collection_id,
	  c.name collection_name,
	  (select handle from handle where resource_id=c.collection_id and resource_type_id=#{RESOURCE_TYPE_IDS[:collection]}) collection_hdl
	from
	  collection c,
	  community2collection com2c
	where
	  com2c.community_id in
	    (select child_comm_id from community2community where parent_comm_id in
	      (select resource_id from handle where handle='#{@era_year_handle}' and resource_type_id=#{RESOURCE_TYPE_IDS[:community]})
	    )
	  and c.collection_id=com2c.collection_id
	  and c.name~'^#{collection_prefix}([^0-9]|$)'
    SQL_HANDLE4COLLECTION_PREFIX
    db_connect{|conn|
      conn.exec(sql){|result|
        if result.ntuples == 1
          result.each{|row| handle = row['collection_hdl']}
        elsif result.ntuples == 0
          STDERR.puts "Quitting: No collection record found when looking up collection prefix #{collection_prefix} for ERA reporting-year with handle #{@era_year_handle}"
          exit 3
        else
          STDERR.puts "Quitting: More than one distinct collection record found when looking up collection prefix #{collection_prefix} for ERA reporting-year with handle #{@era_year_handle}"
          exit 3
        end
      }
    }
    if handle
      @handles_by_prefix[collection_prefix] = handle	# Store in the cache
      @handles_by_prefix[collection_prefix]
    else
      STDERR.puts "Quitting: No handle found for collection prefix #{collection_prefix} for ERA reporting-year with handle #{@era_year_handle}"
      exit 3
    end
  end

  ############################################################################
  # Convert the CSV input file to CSV data sent to stdout. 
  def convert
    STDERR.print "\nThis may take 10 minutes or more. Lines processed: "
    line_in_count = 0

    # Create an object to store *all* lines of the *output* CSV
    @csv_out_data = FasterCSV.generate(FCSV_OUT_OPTS){|csv_out| 

      # Iterate thru each *input* line
      FasterCSV.foreach(@in_file, FCSV_IN_OPTS) {|line_in|
        line_in_count += 1
        if line_in_count == 1
          self.class.verify_csv_in_headers(line_in.headers)
          @csv_out_headers = WILL_INCLUDE_INPUT_COLUMNS ? CSV_OUT_COLUMNS + CSV_IN_COLUMNS : CSV_OUT_COLUMNS
        end

        # Iterate thru each *output* column
        line_out = []
        @csv_out_headers.each_with_index{|col,i|
          csv_out << @csv_out_headers if line_in_count == 1 && i == 0	# Header line

          case col
          when RmidItem, PrefixColOwner, PrefixColList
            line_out << line_in[col]
          when HdlItem
            line_out << get_handle_for_rmid(line_in[RmidItem])
          when HdlColOwner
            line_out << get_handle_for_collection_prefix(line_in[PrefixColOwner])
          when HdlColList
            if line_in[PrefixColList]
              prefixes = line_in[PrefixColList].split(VALUE_DELIMITER)
              handles = prefixes.inject([]){|a,prefix| a << get_handle_for_collection_prefix(prefix)}
              line_out << handles.join(VALUE_DELIMITER)
            else
              line_out << ""
            end
          end
        }
        csv_out << line_out
        STDERR.print "#{line_in_count} " if line_in_count % 200 == 0
      }
    }
    STDERR.puts "; Total lines #{line_in_count} "
  end

  ############################################################################
  # Verify the headers of the CSV input file
  def self.verify_csv_in_headers(headers)
    ok = true
    COLUMN_TRANSLATIONS.each{|csv_in_col,csv_out_col|
      ok = false unless headers.include?(csv_in_col) && !headers.include?(csv_out_col)
    }
    unless ok
      STDERR.puts <<-MSG_CSV_HEADER_ID.gsub(/^\t*/, '')
		The CSV input file must have the column headings:
		  #{CSV_IN_COLUMNS.join(',')}
		and must NOT have the column headings:
		  #{CSV_OUT_COLUMNS.join(',')}
          MSG_CSV_HEADER_ID
      exit 2
    end
  end

  ############################################################################
  # Verify the command line arguments.
  def self.verify_command_line_args
    if ARGV.length != 3 || ARGV.include?('-h') || ARGV.include?('--help')
      STDERR.puts <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0}  RM_FILE.csv  ERA_YEAR_HANDLE  RMID_FROM_HANDLES
		where:
		- RM_FILE.csv contains an extract from RM (ie. your Research Management
		  Information System) with case-sensitive column names:
		    #{CSV_IN_COLUMNS.join(',')}

		- ERA_YEAR_HANDLE is the DSpace handle representing the ERA reporting-year
		  corresponding to RM_FILE.csv. Collection handles shall be derived from this
		  hierarchy.

		- RMID_FROM_HANDLES contain a comma-separated list (without spaces) of ERA
		  reporting-year (community) handles representing the *range* of communities
		  in which RMIDs in RM_FILE.csv shall be found. If the corresponding RMIDs
		  are permitted to be found anywhere within the DSpace database, use the
		  word 'any' for this parameter.

		  Example 1: If this is the first ERA reporting-year which you have entered
		  into DSpace, and you want this program to only search for RMIDs from this
		  ERA reporting-year, then repeat the ERA_YEAR_HANDLE for this parameter.

		  Example 2: 
		  * Assume the target ERA reporting-year is ERA 2015 (which has a reporting
		    period of 1 Jan 2008 to 31 Dec 2013).
		  * Assume that ERA metadata has been loaded into DSpace for ERA 2010
		    (which has a reporting period of 1 Jan 2003 to 31 Dec 2008) and
		    ERA 2012 (which has a reporting period of 1 Jan 2005 to 31 Dec 2010).
		    Hence you can see that some ERA 2015 research outputs may also
		    appear in ERA 2010 and ERA 2012.
		  * Assume that RMIDs exist in other areas of DSpace but you only wish to use
		    those found within ERA 2010, 2012 and 2015 reporting-year communities.
		  Hence, this RMID_FROM_HANDLES parameter should be look something like:
		      123456789/1,123456789/9,123456789/15
		  where these handles correspond to ERA 2010, ERA 2012 and ERA 2015
		  reporting-year communities.

		This application converts the RM-CSV input columns:
		    #{CSV_IN_COLUMNS.join(',')}
		to the Handle-CSV output columns:
		    #{CSV_OUT_COLUMNS.join(',')}
		respectively.

      MSG_COMMAND_LINE_ARGS
      exit 1
    end
  end

  public

  ############################################################################
  # The main method for this class.
  def self.main
    verify_command_line_args
    fname = ARGV[0]
    era_year_handle = ARGV[1]
    rmid_from_era_year_handles_string = ARGV[2]

    STDERR.puts "\nConvert an RM-CSV file to a Handle-CSV file for the given ERA reporting-year"
    STDERR.puts   "----------------------------------------------------------------------------"

    csv_out = RmCsv2HandleCsv.new(fname, era_year_handle, rmid_from_era_year_handles_string)
    STDERR.puts
    puts csv_out
  end

end

##############################################################################
# Main
##############################################################################
  RmCsv2HandleCsv.main
  exit 0

