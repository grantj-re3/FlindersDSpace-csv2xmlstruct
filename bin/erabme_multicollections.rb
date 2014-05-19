#!/usr/bin/ruby
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
#
# For any ERA item for the target ERA reporting year (extracted
# from the Research MIS) which we have already imported into DSpace
# (either in the target or previous reporting years) this script
# will create a BMET CSV file which will map the item to all
# collections to which it belongs.
#
# ALGORITHM
#
# - Iterate through each item in the target ERA reporting year CSV
#   (eg. ERA 2012). For each item:
#   * If the item appears once in the target ERA reporting year and
#     one or more times in previous ERA reporting years, then mark
#     the item for processing.
#   * If the item appears two or more times in the target ERA reporting
#     year and zero or more times in previous ERA reporting years,
#     then mark the item for processing.
# - Iterate through all marked items. For each item:
#   * Create a record in a BMET CSV file which maps the item to all
#     collections in the target and previous ERA reporting years.
# - Run the DSpace BMET against the newly created BMET CSV file
#
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << File.expand_path("../lib/libext", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

require 'collections_by_item'
require 'dspace_utils'

##############################################################################
# A class for representing and processing a DSpace Batch Metadata Editing
# Tool (BMET) CSV file
##############################################################################
class BmetCsv
  include DSpaceUtils

  DEBUG = true		# true = Add extra CSV columns to assist debugging

  ############################################################################
  # Create this object. target_year_csv and previous_year_csv are CSV
  # filenames representing the target ERA reporting-year (ie. the
  # items being newly ingested into DSpace) and previous ERA
  # reporting-years (ie. items which already existed within
  # DSpace before the "target ERA reporting-year" ingest process
  # began. The previous_year_csv is permitted to be nil.
  ############################################################################
  def initialize(target_year_csv, previous_year_csv)

    @target_collection_list = CollectionsByItem.new(target_year_csv)
    @target_collection_list.load_csv

    if previous_year_csv
      @prev_collection_list = CollectionsByItem.new(previous_year_csv)
      @prev_collection_list.load_csv
    else
      @prev_collection_list = nil
    end

    # Items in the target year which belong to more than one collection.
    # These will need to be processed further by producing a BMET CSV
    # file which will allow each item to be mapped to all associated
    # collections.
    @merged_collection_list = @target_collection_list.merge(@prev_collection_list)

    # For interest only. List which items remain (ie. items in the target
    # year which belong to only a single collection)
    ##@exclusive_collection_list = @target_collection_list.exclude(@merged_collection_list)
  end

  ############################################################################
  # Convert object to string
  ############################################################################
  def to_s
    @merged_collection_list.to_csv
  end

  ############################################################################
  # Convert remaining (exclusive) list to string
  ############################################################################
  def to_s_exclusive
    @exclusive_collection_list.to_csv
  end

  private

  ############################################################################
  # Verify the command line arguments
  ############################################################################
  def self.verify_command_line_args
    if ARGV.length == 0 || ARGV.length > 2 || ARGV.include?('-h') || ARGV.include?('--help')
      STDERR.puts <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0}  TARGET_ERA_REPORTING_YEAR_CSV PREVIOUS_ERA_REPORTING_YEARS_CSV
		  where
		    TARGET_ERA_REPORTING_YEAR_CSV is the CSV file listing handles
		    corresponding to items and their collections for the target
		    ERA reporting year. The target year is the year being imported
		    from your Research Management Information System and has a
		    corresponding directory tree containing multiple DSpace
		    collections which conform to the Simple Archive Format (SAF).

		    PREVIOUS_ERA_REPORTING_YEARS_CSV is the CSV file listing handles
		    corresponding to items and their collections for all ERA reporting
		    years prior to the target year.

		    Both the above CSV files have the following columns:
		      #{CollectionsByItem::CSV_IN_FIELDS.each{|f| f.to_s}.join(',')}
      MSG_COMMAND_LINE_ARGS
      exit 1
    end
  end

  public

  ############################################################################
  # The main method for this class
  ############################################################################
  def self.main
    verify_command_line_args

    STDERR.puts "\nCreating a BMET CSV file for allocating ERA items to multiple collections"
    STDERR.puts   "-------------------------------------------------------------------------"

    target_year_csv = ARGV.shift
    previous_year_csv = ARGV.shift

    STDERR.printf "Target ERA reporting-year CSV file:    %s\n", target_year_csv
    STDERR.printf "Previous ERA reporting-years CSV file: %s\n", previous_year_csv ? previous_year_csv : '(None)'
    STDERR.puts

    CollectionsByItem.begin_lookup_by_handle if DEBUG
    bmet_csv = BmetCsv.new(target_year_csv, previous_year_csv)
    puts bmet_csv.to_s
    CollectionsByItem.end_lookup_by_handle if DEBUG
  end
end

##############################################################################
# Main
##############################################################################
BmetCsv.main
exit 0

