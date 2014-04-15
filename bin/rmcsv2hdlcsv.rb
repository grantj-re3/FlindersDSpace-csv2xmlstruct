#!/usr/bin/ruby
# rmcsv2hdlcsv.rb
# 
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
# Convert RM-CSV file for a specified ERA reporting year with columns:
#   RMID,FOR4D_Owner,FOR4D_Others
#
# to a Handle-CSV file with columns:
#   ItemHdl,Col_Owner_Hdl,Col_Others_Hdl
#
##############################################################################

# Add dirs to the library path
$: << File.expand_path(".", File.dirname(__FILE__))
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << File.expand_path("../lib/libext", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

require 'faster_csv'
require 'rubygems'
require 'pg'
require 'pg_extra'
require 'dbc'

##############################################################################
class RmCsv2HandleCsv
  include DbConnection

  # In the output-CSV, include input-CSV columns which are being translated
  WILL_INCLUDE_INPUT_COLUMNS = true

  # In a single CSV column, use this delimiter to separate multiple values
  VALUE_DELIMITER = '||'

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

  # This hash shows the relationship between the DSpace handle table's
  # resource_type_id and its type.
  RESOURCE_TYPE_IDS = {
    :item	=> 2,
    :collection	=> 3,
    :community	=> 4,
  }

  attr_reader :in_file, :era_year_handle, :csv_out_headers, :csv_out_data

  ############################################################################
  # Create a new object from the specified CSV input file.
  def initialize(csv_in_filename, era_year_handle)
    @in_file = csv_in_filename
    verify_in_file

    @db_conn = PG::Connection.connect(DB_CONNECT_INFO)	# Connect to the DB
    @era_year_handle = era_year_handle
    verify_era_year_handle

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
  # Yield a connection to the DSpace database. If @db_conn is nil we
  # will open and yield a new connection. Otherwise we assume that
  # @db_conn is a valid connection and we will yield it.
  def db_connect
    yield @db_conn ? @db_conn : PG::Connection.connect2(DB_CONNECT_INFO)
  end

  ############################################################################
  # Verify the RM-CSV input file
  def verify_in_file
    unless File.file?(@in_file) && File.readable?(@in_file)
      STDERR.puts "CSV file '#{@in_file}' is not found or is not readable."
      exit 6
    end

  end

  ############################################################################
  # Verify the ERA reporting-year handle
  def verify_era_year_handle
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
          result.each{|row| STDERR.puts "ERA reporting-year community name: #{row['name']}" }
        end
      }
    }
  end

  ############################################################################
  # Return the handle for the specified RMID. Quit unless the RMID maps
  # to exactly one handle and the handle is not null.
  def get_handle_for_rmid(rmid)
    handle = nil
    sql = <<-SQL_HANDLE4RMID.gsub(/^\t*/, '')
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
	        (select resource_id from handle where handle='#{@era_year_handle}' and resource_type_id=#{RESOURCE_TYPE_IDS[:community]})
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
    SQL_HANDLE4RMID
    db_connect{|conn|
      conn.exec(sql){|result|
        if result.ntuples == 1
          result.each{|row| handle = row['item_hdl']}
        elsif result.ntuples == 0
          STDERR.puts "Quitting: No item record found when looking up RMID #{rmid} for ERA reporting-year with handle #{@era_year_handle}"
          exit 4
        else
          STDERR.puts "Quitting: More than one distinct item record found when looking up RMID #{rmid} for ERA reporting-year with handle #{@era_year_handle}"
          exit 4
        end
      }
    }
    if handle
      handle
    else
      STDERR.puts "Quitting: No handle found for the item with RMID #{rmid} for ERA reporting-year with handle #{@era_year_handle}"
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
    # Create an object to store *all* lines of the *output* CSV
    @csv_out_data = FasterCSV.generate(FCSV_OUT_OPTS){|csv_out| 

      # Iterate thru each *input* line
      line_in_count = 0
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
            prefixes = line_in[PrefixColList].split(VALUE_DELIMITER)
            handles = prefixes.inject([]){|a,prefix| a << get_handle_for_collection_prefix(prefix)}
            line_out << handles.join(VALUE_DELIMITER)
          end
        }
        csv_out << line_out
      }
    }
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
    if ARGV.length != 2 || ARGV.include?('-h') || ARGV.include?('--help')
      STDERR.puts <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0}  RM_FILE.csv  ERA_YEAR_HANDLE
		where:
		- RM_FILE.csv contains an extract from RM (ie. your
		  Research Management Information System) with columns:
		    #{CSV_IN_COLUMNS.join(',')}
		- ERA_YEAR_HANDLE is the DSpace handle representing the
		  ERA reporting-year corresponding to RM_FILE.csv

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

    STDERR.puts "\nConvert an RM-CSV file to a Handle-CSV file for the given ERA reporting-year"
    STDERR.puts   "----------------------------------------------------------------------------"
    STDERR.puts "RM input-CSV filename: #{fname}"
    STDERR.puts "ERA reporting-year community handle: #{era_year_handle}"

    csv_out = RmCsv2HandleCsv.new(fname, era_year_handle)
    STDERR.puts
    puts csv_out
  end

end

##############################################################################
# Main
##############################################################################
  RmCsv2HandleCsv.main
  exit 0

