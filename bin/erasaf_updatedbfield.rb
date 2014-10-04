#!/usr/bin/ruby
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
#
# For any ERA item for the target ERA reporting year (extracted
# from the Research MIS) which we have already imported into DSpace
# in previous reporting years (ie. which have already been plucked
# out of the SAF tree) this script will create a BMET CSV file which
# will update some of the fields (in particular dc.type or
# dc.subject.forgroup depending on the command line arguments).
#
# ALGORITHM
#
# - Iterate through each SAF-plucked-out items
#   * Gather list of the target-field(s) from SAF-tree
#   * Gather list of the target-field(s) from DB
#   * Gather list of the target-field languages from DB
#   * If DB field updates are needed (based on comparing SAF with
#     DB fields) then create a BMET CSV file to add/replace fields
#++
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << File.expand_path("../lib/libext", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

require 'rexml/document'
require 'rexml/xpath'
require 'faster_csv'
require 'dspace_utils'
require 'object_extra'
require 'rubygems'
require 'pg'
require 'pg_extra'
require 'dbc'

##############################################################################
# A class for representing and updating DSpace database items. In
# particular, for updating specified database item-fields with newer
# information from Simple Archive Format (SAF) information (from your
# Research Management Information System, RMIS, for a given ERA-year).
# This program will produce a CSV file suitable for updating the fields
# using the DSpace Batch Metadata Editing Tool (BMET).
##############################################################################
class Items4FieldUpdates
  #include DSpaceUtils
  include DbConnection
  include DSpaceUtils

  DEBUG = true

  ID_OR_HANDLE = :id	# :id=Use BMET 'id' column; :handle=Use 'handle' column

  CSV_DELIMITER = ','
  CSV_QUOTE = '"'
  CSV_FILENAME_PREFIX = "#{File.basename($0, '.rb')}_"

  # FasterCSV options for reading CSV file
  FCSV_OPTS = {
    :col_sep => CSV_DELIMITER,
    :headers => true,
    :header_converters => :symbol,
  }

  # Set the same as default.language in dspace.cfg.
  # This constant can be set to nil (but not recommended for DSpace BMET usage)
  DSPACE_FIELD_LANGUAGE = 'en_US'

  COMMAND_LINE_SWITCHES = %w{add_forgroups replace_type}

  ############################################################################
  # Create this object which
  # processes items which have already been plucked out of the RMIS
  # SAF-tree because they already exist in the database. (Hence these
  # items were not included in the SAF import.) The processing involves
  # updating certain database fields based on newer information in the
  # RMIS SAF-tree (if applicable). See the usage message in the method
  # verify_command_line_args(), where:
  # - cmd_switch = SWITCH
  # - plucked_out_items_csv = PLUCKED_OUT_ITEMS.CSV
  # - plucked_out_dir = PLUCKED_OUT_DIR
  ############################################################################
  def initialize(cmd_switch, plucked_out_items_csv, plucked_out_dir)
    @cmd_switch = cmd_switch	# What type of field-processing will be done

    # Items which have already been plucked out of the RMIS SAF tree because
    # they already exist in the DB. Hence these items were not included in
    # the SAF import.
    @plucked_out_items_csv = plucked_out_items_csv
    @plucked_out_dir = plucked_out_dir

    @items_from_saf = {}	# SAF item list with focus on specified field
    gather_from_plucked_saf

    @items_from_db = {}		# DB item list with focus on specified field
    @langs_in_db = Set.new	# DB language used for specified field
    gather_from_db

    @csv_info = {}		# Subset of items which need specified field updated
  end

  private

  ############################################################################
  # Populate @items_from_saf with items listed in CSV file
  # @plucked_out_items_csv having:
  # - fields specified by @cmd_switch, and
  # - field values read from the plucked-out SAF-tree at
  #   @plucked_out_dir/FORCODE_DIR/RMID_DIR/dublin_core.xml
  ############################################################################
  def gather_from_plucked_saf
    have_found_error = false
    @items_from_saf = gather_from_csv

    @items_from_saf.each{|item_id, item|

      rmid = item[:rmid]	# Assumes RMID already checked for nil
      glob_str = "#{@plucked_out_dir}/*/#{rmid}/dublin_core.xml"
      files = Dir.glob(glob_str)
      if files.length == 1
        doc_str = File.read(files.first)

        fields = []		# Storage for multi-value field
        doc = REXML::Document.new(doc_str)
        doc.elements.each(xpath4saf_field){|e| fields << {:value => e.text}}

      else
        STDERR.puts "ERROR: #{rmid} found #{files.length} times in glob:\n  #{glob_str}"
        have_found_error = true
      end
      @items_from_saf[item_id][:fields] = fields
    }
    exit 2 if have_found_error
    STDERR.puts "\n@items_from_saf=#{@items_from_saf.inspect}\n\n" if DEBUG
  end

  ############################################################################
  # Populate @items_from_db with items listed in CSV file
  # @plucked_out_items_csv having:
  # - fields specified by @cmd_switch, and
  # - field values read from the DSpace database
  ############################################################################
  def gather_from_db
    @items_from_db = gather_from_csv
    @items_from_db.each_key{|item_id| @items_from_db[item_id][:fields] = get_item_fields_from_db(item_id)}
    STDERR.puts "\n@items_from_db=#{@items_from_db.inspect}" if DEBUG
  end

  ############################################################################
  # Return a subset of fields for each item read from the file
  # @plucked_out_items_csv. These fields will be augmented by more
  # fields from either the plucked-out SAF-tree or database sources
  # (to populate @items_from_saf or @items_from_db respectively).
  ############################################################################
  def gather_from_csv
    items = {}
    FasterCSV.foreach(@plucked_out_items_csv, FCSV_OPTS){|line|
      STDERR.puts "ERROR: RMID not found for item_id #{line[:item_id].chomp} in CSV-file #{@plucked_out_items_csv}" unless line[:rmid]
      items[ line[:item_id].chomp ] = {
        :handle => line[:item_hdl].chomp,
        :rmid => line[:rmid].chomp,
        #:collection_handle => line[:col_owner_hdl].chomp,
      }
    }
    items
  end

  ############################################################################
  # Extract and return the specified item fields from the database.
  ############################################################################
  def get_item_fields_from_db(item_id)
    sql = <<-SQL_GET_ITEM_FIELDS.gsub(/^\t*/, '')
	select
	  mdv.text_value,
	  mdv.text_lang,
	  mdv.item_id,
	  mdfr.element,
	  mdfr.qualifier
	from
	  metadatavalue mdv,
	  metadatafieldregistry mdfr
	where
	  item_id = #{item_id} and
	  mdv.metadata_field_id = mdfr.metadata_field_id and
	  #{element_qualifier_where_clause}
	order by 1
    SQL_GET_ITEM_FIELDS

    fields = []		# Storage for multi-value field
    PG::Connection.connect2(DB_CONNECT_INFO){|conn|
      conn.exec(sql){|result|
        result.each{|row|
          fields << {:value => row['text_value'], :lang  => row['text_lang']} 
        }
      }
    }
    STDERR.printf("WARNING: No %s found for item %s within DB\n", field_name, item_id) unless fields.length > 0
    fields
  end

  ############################################################################
  # Return the XPath string which will extract the specified field
  # from the SAF file dublin_core.xml.
  ############################################################################
  def xpath4saf_field
    case @cmd_switch
    when 'add_forgroups'
      "/dublin_core/dcvalue[@element='subject' and @qualifier='forgroup']"

    when 'replace_type'
      "/dublin_core/dcvalue[@element='type' and not(@qualifier)]"

    else
      STDERR.puts "Invalid command line switch: #{@cmd_switch}"
      exit 1
    end
  end

  ############################################################################
  # Return the SQL where-clause string to extract the specified field
  # from the DSpace database.
  ############################################################################
  def element_qualifier_where_clause
    case @cmd_switch
    when 'add_forgroups'
      "mdfr.element = 'subject' and mdfr.qualifier = 'forgroup'"

    when 'replace_type'
      "mdfr.element = 'type' and mdfr.qualifier is null"

    else
      STDERR.puts "Invalid command line switch: #{@cmd_switch}"
      exit 1
    end
  end

  ############################################################################
  # Return the Qualified Dublin Core field-name string in the form
  # 'dc.FIELD[.QUALIFIER]' where the component within square brackets
  # may not be present.
  ############################################################################
  def field_name
    case @cmd_switch
    when 'add_forgroups'
      'dc.subject.forgroup'

    when 'replace_type'
      'dc.type'

    else
      STDERR.puts "Invalid command line switch: #{@cmd_switch}"
      exit 1
    end
  end

  ############################################################################
  # For each item, determine if the specified field needs to be updated
  # within the database. If so, add the item-record to the BMET CSV file.
  ############################################################################
  def to_bmet_csv_add_forgroups
    # A forgroup name has the format "0101 - Pure Mathematics"
    # or surprising, even the format "0101\n       - Pure Mathematics"
    # where "0101" is the forcode.
    @langs_in_db = Set.new
    @csv_info = {}
    forcode_regex = Regexp.new('^([\d]+)([^\d].*$|$)', Regexp::MULTILINE)

    @items_from_db.each{|item_id,db_hash|
      fields_in_db = Set.new
      fields_in_saf = Set.new
      field_values = {}		# Field values for both DB & SAF

      db_hash[:fields].each{|f|
        forcode = f[:value].sub(forcode_regex, '\1')
        fields_in_db << forcode
#STDERR.puts "@@@ db_hash item_id=#{item_id} forcode=#{forcode}"
        field_values[forcode] = f[:value].gsub(/[\s]+/, ' ')	# Store value for this FOR code
        @langs_in_db << f[:lang]
      }

      @items_from_saf[item_id][:fields].each{|f|
        forcode = f[:value].sub(forcode_regex, '\1')
        fields_in_saf << forcode
#STDERR.puts "@@@ items_from_saf item_id=#{item_id} forcode=#{forcode}"
        field_values[forcode] = f[:value].gsub(/[\s]+/, ' ')	# Store/overwrite value for this FOR code
      }
      STDERR.printf("item_id=%s; item-hdl=%s; SAF-fields=%s; DB-fields=%s", item_id, db_hash[:handle], fields_in_saf.inspect, fields_in_db.inspect) if DEBUG
      extra_fields = fields_in_saf - fields_in_db	# Extra fields not already in DB

      if extra_fields.size > 0
        @csv_info[item_id] = {
          #:collection_handle => db_hash[:collection_handle],
          :new_field_values => (fields_in_db | extra_fields).inject(Set.new){|s,forcode| s << field_values[forcode]},
          :handle => db_hash[:handle],
        }
        STDERR.puts "; DB-add #{extra_fields.inspect}" if DEBUG
      else
        STDERR.puts "; No updates" if DEBUG
      end
    }
    build_csv
  end

  ############################################################################
  # For each item, determine if the specified field needs to be updated
  # within the database. If so, add the item-record to the BMET CSV file.
  ############################################################################
  def to_bmet_csv_replace_type
    @langs_in_db = Set.new
    @csv_info = {}
    have_found_error = false

    @items_from_db.each{|item_id,db_hash|
      fields_in_db = Set.new
      fields_in_saf = Set.new
      field_values = {}		# Field values for both DB & SAF

      db_hash[:fields].each{|f|
        fields_in_db << f[:value]
        @langs_in_db << f[:lang]
      }

      @items_from_saf[item_id][:fields].each{|f|
        fields_in_saf << f[:value]
      }
      if fields_in_db.size == 0
        STDERR.puts "WARNING: item_id #{item_id} (RMID #{db_hash[:rmid]}; handle #{db_hash[:handle]}) has no dc.type field in DB; adding from SAF"
      end

      if fields_in_db.size > 1
        STDERR.puts "ERROR: item_id #{item_id} (RMID #{db_hash[:rmid]}; handle #{db_hash[:handle]}) has #{fields_in_db.size}x dc.type fields in DB"
        have_found_error = true
      end

      unless fields_in_saf.size == 1
        STDERR.puts "ERROR: item_id #{item_id} (RMID #{db_hash[:rmid]}; handle #{db_hash[:handle]}) has #{fields_in_saf.size}x dc.type fields in SAF"
        have_found_error = true
      end

      next if have_found_error			# Skip processing this item_id if errors
      STDERR.printf("item_id=%s; item-hdl=%s; SAF-fields=%s; DB-fields=%s", item_id, db_hash[:handle], fields_in_saf.inspect, fields_in_db.inspect) if DEBUG

      # No update needed if dc.type already same for DB & SAF
      unless fields_in_db == fields_in_saf
        @csv_info[item_id] = {
          #:collection_handle => db_hash[:collection_handle],
          :new_field_values => fields_in_saf.inject(Set.new){|s,type| s << type},
          :handle => db_hash[:handle],
        }
        STDERR.puts "; DB-replace-with #{@csv_info[item_id][:new_field_values].inspect}" if DEBUG
      else
        STDERR.puts "; No updates" if DEBUG
      end

    }
    exit 3 if have_found_error
    build_csv
  end

  ############################################################################
  # Build the BMET CSV-file text from @csv_info and write the results
  # to a file. The specified field (given by field_name()) of each
  # item in the BMET CSV-file shall have the language DSPACE_FIELD_LANGUAGE.
  # The information in @langs_in_db shall be used to force the specified
  # field in other languages to be blank within the BMET CSV-file. This
  # is needed to prevent multiple copies of the same field values
  # appearing (in different languages) after running a BMET-import.
  ############################################################################
  def build_csv
    STDERR.puts "\n@csv_info=#{@csv_info.inspect}" if DEBUG
    if @csv_info.empty?
      STDERR.puts "No changes are required, so no BMET CSV file has been created."
      return
    end

    other_csv_langs = @langs_in_db - Set.new([DSPACE_FIELD_LANGUAGE])
    empty_fields_str = CSV_DELIMITER * other_csv_langs.size
    lines = []		# An array of CSV lines

    # Build the CSV header-line
    lang_str = DSPACE_FIELD_LANGUAGE ? "[#{DSPACE_FIELD_LANGUAGE}]" : ''
    hdr_main_columns = [ "#{ID_OR_HANDLE}", field_name + lang_str ]

    hdr_other_columns = other_csv_langs.inject([]){|a, lang|
      a << field_name + (lang ? "[#{lang}]" : '')
    }
    # Sort hdr_other_columns so that CSV header is deterministic
    lines << (hdr_main_columns + hdr_other_columns.sort).join(CSV_DELIMITER)

    # Build the CSV item-lines
    @csv_info.sort.each{|item_id, r|
      item = ID_OR_HANDLE == :handle ? r[:handle] : item_id
      lines << "#{CSV_QUOTE}#{item}#{CSV_QUOTE}#{CSV_DELIMITER}" +
        "#{CSV_QUOTE}#{r[:new_field_values].sort.to_a.join(VALUE_DELIMITER)}#{CSV_QUOTE}#{empty_fields_str}"
    }
    fname = "#{CSV_FILENAME_PREFIX}#{@cmd_switch}.#{ID_OR_HANDLE}.csv"
    STDERR.puts "Writing BMET CSV-data to file '#{fname}'"
    File.write_string(fname, lines.join(NEWLINE) + NEWLINE)
  end

  ############################################################################
  # Verify the command line arguments
  ############################################################################
  def self.verify_command_line_args
    msg = <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0}  SWITCH PLUCKED_OUT_ITEMS.CSV PLUCKED_OUT_DIR
		where
		  SWITCH is either 'add_forgroups' or 'replace_type'

		  'add_forgroups' switch: This program will compare each item's
		  list of dc.subject.forgroup fields in the DSpace database with
		  those in the Research MIS data (in the Simple Archive Format
		  (SAF) tree specified by PLUCKED_OUT_DIR).  If the RMIS data
		  for a particular item contains any additional dc.subject.forgroup
		  fields, those extra fields will be added to the database (by
		  running this script and importing the resulting CSV file using
		  the DSpace Batch Metadata Editing Tool).

		  'replace_type' switch: This program will compare each item's
		  dc.type field in the DSpace database with that in the Research
		  MIS data (in the Simple Archive Format (SAF) tree specified by
		  PLUCKED_OUT_DIR). If the two fields are different, the database
		  copy of the field will be replaced with the SAF copy (by
		  running this script and importing the resulting CSV file using
		  the DSpace Batch Metadata Editing Tool). It expects one dc.type
		  field per item.

		  PLUCKED_OUT_ITEMS.CSV is a subset of the CSV file produced from
		  running itemHdl_colHdl_ResearchPubEra.sh (or itemHdl_colHdl_AllPub.sh).
		  The subset must only contain items which have been "plucked out"
		  of the SAF-tree with erasaf_pluckitem.rb. (See the project
		  documentation describing how you can do this with
		  plucked_items_regex.txt.) The minimum set of CSV columns required
		  by this program are:
		    item_id,item_hdl,rmid

		  PLUCKED_OUT_DIR is the directory resulting from running
		  erasaf_pluckitem.rb on the ERA-year Research MIS data. It only
		  contains data which was already present within DSpace and so
		  was "plucked out" of the ERA-year SAF-tree prior to SAF-import
		  into DSpace.
    MSG_COMMAND_LINE_ARGS

    if ARGV.include?('-h') || ARGV.include?('--help')
      STDERR.puts msg
      exit 0
    end

    unless ARGV.length == 3
      STDERR.puts "\nERROR: Expected 3 arguments, but #{ARGV.length} were entered.\n#{msg}"
      exit 4
    end

    cmd_switch = ARGV[0]
    plucked_out_items_csv = ARGV[1]
    plucked_out_dir = ARGV[2]

    unless COMMAND_LINE_SWITCHES.include?(cmd_switch)
      STDERR.puts "\nERROR: Invalid command line switch: '#{cmd_switch}'\n#{msg}"
      exit 1
    end

    unless File.file?(plucked_out_items_csv)
      STDERR.puts "\nERROR: '#{plucked_out_items_csv}' is not a (CSV) file.\n#{msg}"
      exit 5
    end

    unless File.directory?(plucked_out_dir)
      STDERR.puts "\nERROR: '#{plucked_out_dir}' is not a (SAF) directory.\n#{msg}"
      exit 6
    end
  end

  public

  ############################################################################
  # Create a BMET CSV file for the specified field.
  ############################################################################
  def to_bmet_csv
    case @cmd_switch
    when 'add_forgroups'
      to_bmet_csv_add_forgroups
    when 'replace_type'
      to_bmet_csv_replace_type
    else
      STDERR.puts "Invalid command line switch: #{@cmd_switch}"
      exit 1
    end
  end

  ############################################################################
  # The main method for this class
  ############################################################################
  def self.main
    verify_command_line_args

    STDERR.puts "\nCreating a BMET CSV file for updating a field"
    STDERR.puts   "---------------------------------------------"

    cmd_switch = ARGV[0]
    plucked_out_items_csv = ARGV[1]
    plucked_out_dir = ARGV[2]

    STDERR.printf "Command line switch:          %s\n", cmd_switch
    STDERR.printf "Plucked-out items CSV file:   %s\n", plucked_out_items_csv
    STDERR.printf "Plucked-out items directory:  %s\n", plucked_out_dir
    STDERR.printf "Output CSV-key column:        %s\n", ID_OR_HANDLE.to_s
    STDERR.puts

    items = Items4FieldUpdates.new(cmd_switch, plucked_out_items_csv, plucked_out_dir)
    items.to_bmet_csv
  end

  alias to_csv to_bmet_csv
end

##############################################################################
# Main
##############################################################################
Items4FieldUpdates.main
exit 0

