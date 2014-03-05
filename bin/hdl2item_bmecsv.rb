#!/usr/bin/ruby
# hdl2item_bmecsv.rb
# 
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
# Convert handle to item_id for the DSpace 3.x Batch Metadata Editing
# Tool (BMET) CSV file.
#
# Typically, we like to reference DSpace items via their handle, but
# the BMET will only accept the item_id in the 'id' field. This script
# can be used with the following workflow.
# - create a BMET CSV file, but with the item-handle instead of the id
# - run this script to convert item-handle into the (item) id
# - import the CSV file into DSpace using the command:
#     dspace metadata-import ...
##############################################################################

# Add dirs to the library path
$: << "../lib"
$: << "../lib/libext"

# Use main() from this file unless already defined
MAIN_CLASS = :CsvConverter unless defined?(MAIN_CLASS)

require 'faster_csv'
require 'object_extra'
require 'dspace_resource'

##############################################################################
class CsvConverter

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
  COLUMN_ITEM_HANDLE = 'item_handle'	# Replace this column (representing item handle)
  COLUMN_ITEM_ID = 'id'			# with this column (representing item ID)

  # Exit codes for errors
  ERROR_BASE = 40
  ERROR_HANDLE_LOOKUP		= ERROR_BASE + 1
  ERROR_CSV_HEADER_ID		= ERROR_BASE + 2
  ERROR_CSV_HEADER_COLLECTION	= ERROR_BASE + 3
  ERROR_COMMAND_LINE_ARGS	= ERROR_BASE + 4

  attr_reader :in_file, :csv_out_headers, :index, :csv_out_data

  ############################################################################
  # Create a new object from the specified CSV input file.
  def initialize(csv_in_filename)
    @in_file = csv_in_filename
    @csv_out_headers = nil
    @index = nil
    @csv_out_data = nil
    convert
  end

  ############################################################################
  # Convert the CSV input file to CSV data sent to stdout. 
  # Handles in the COLUMN_ITEM_HANDLE column shall be replaced
  # in the output by item_ids in the COLUMN_ITEM_ID column.
  def convert
    # Create an object to store *all* lines of the *output* CSV
    @csv_out_data = FasterCSV.generate(FCSV_OUT_OPTS){|csv_out| 

      # Iterate thru each *input* line
      line_in_count = 0
      FasterCSV.foreach(@in_file, FCSV_IN_OPTS) {|line_in|
        line_in_count += 1
        if line_in_count == 1
          self.class.verify_csv_in_headers(line_in.headers)
          # The output CSV shall be indentical to the input CSV but with
          # the COLUMN_ITEM_HANDLE replaced with COLUMN_ITEM_ID.
          @csv_out_headers = line_in.headers.deep_copy
          @index = @csv_out_headers.index(COLUMN_ITEM_HANDLE) # Index of column to be replaced
          @csv_out_headers[@index] = COLUMN_ITEM_ID	# Replace this column in the header
        end

        # Iterate thru each *output* column
        line_out = []
        @csv_out_headers.each_with_index{|col,i|
          csv_out << @csv_out_headers if i == 0		# Header line

          unless i == @index
            line_out << line_in[col]
          else						# Replace with item_id
            h = DSpaceResource.new(line_in[COLUMN_ITEM_HANDLE], :item)
            if h && h.resource_id
              line_out << h.resource_id			# The item_id corresponding to handle
            else
              STDERR.puts <<-HANDLE_LOOKUP_MSG.gsub(/^\t*/, '')
		ERROR: Either the handle '#{line_in[COLUMN_ITEM_HANDLE]}' was not found or it was
		found but the corresponding item_id is NULL (eg. perhaps the item was
		deleted from the database).
              HANDLE_LOOKUP_MSG
              exit ERROR_HANDLE_LOOKUP
            end
          end
        }
        csv_out << line_out
      }
    }
  end

  ############################################################################
  # Verify the headers of the CSV input file
  def self.verify_csv_in_headers(headers)
    unless headers.include?(COLUMN_ITEM_HANDLE) && !headers.include?(COLUMN_ITEM_ID)
          STDERR.puts <<-CSV_HEADER_ID_MSG.gsub(/^\t*/, '')
		The CSV input file must NOT have the column heading '#{COLUMN_ITEM_ID}' and must have
		the column heading '#{COLUMN_ITEM_HANDLE}'. The '#{COLUMN_ITEM_HANDLE}' represents the item's
		handle eg. 123456789/111. In the CSV output, this column will be removed
		and replaced with column heading '#{COLUMN_ITEM_ID}' representing the item's id eg. 222.
          CSV_HEADER_ID_MSG
      exit ERROR_CSV_HEADER_ID
    end
    # Although DSpace BMET does not seem to consider this an error, this
    # app will consider it an error as the only reason to run this app at
    # this stage is to add the item to multiple collections.
    unless headers.include?('collection')
          STDERR.puts <<-CSV_HEADER_COLLECTION_MSG.gsub(/^\t*/, '')
		The CSV input file must have the column heading 'collection' representing
		the collection or collections to which the item belongs. Either the
		collection handle or collection ID can be used and multiple collections
		can be specified by using the delimiter specified in the DSpace manual
		(usually '||').
          CSV_HEADER_COLLECTION_MSG
      exit ERROR_CSV_HEADER_COLLECTION
    end
  end

  ############################################################################
  # Represent object as a string.
  def to_s
    @csv_out_data
  end

  ############################################################################
  # Verify the command line arguments.
  def self.verify_command_line_args
    unless ARGV.length == 1 && File.file?(ARGV[0]) && File.readable?(ARGV[0])
      STDERR.puts <<-COMMAND_LINE_ARGS_MSG.gsub(/^\t*/, '')
		Usage:  #{File.basename $0} FILE.csv
		  where FILE.csv is compatible with the Batch Metadata Editing Tool
		  (BMET) except the DSpace items shall be specified via their handle
		  in a new column '#{COLUMN_ITEM_HANDLE}'.

		Since the DSpace BMET does not permit items to be specified by their
		handle, the purpose of this application is to allow such a CSV file
		then convert it into a format compatible with BMET.

		That is, this application converts the '#{COLUMN_ITEM_HANDLE}' column of
		FILE.csv into the '#{COLUMN_ITEM_ID}' column on the standard output.

      COMMAND_LINE_ARGS_MSG
      exit ERROR_COMMAND_LINE_ARGS
    end
  end

  ############################################################################
  # The main method for this class.
  def self.main
    verify_command_line_args
    fname = ARGV[0]
    csv_out = CsvConverter.new(fname)
    puts csv_out
  end

end

##############################################################################
# Main
##############################################################################
if MAIN_CLASS == :CsvConverter
  CsvConverter.main
  exit 0
end

