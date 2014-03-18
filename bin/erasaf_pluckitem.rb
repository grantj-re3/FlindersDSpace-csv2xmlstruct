#!/usr/bin/ruby
# erasaf_pluckitem.rb
# 
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
# Check if items (ie. RMIDs) from any of the specified CSV files
# are found in the specified ERA Simple Archive Format (SAF) tree.
# If so, extract the item by moving it to an identical hierarchical
# position in a destination tree (for potential future processing
# by the DSpace Batch Metadata Editing Tool, BMET).
# 
# ERA SAF directories shall be arranged in the following hierarchy.
# 
# ERA_YEAR [community]
# - FOR4DIGIT_A [collection]
#   * RMID_A01 [item]
#     - SAF files for this item
#   * RMID_A02 [item]
#     - SAF files for this item
#   * ...
# - FOR4DIGIT_B [collection]
#   * RMID_B01 [item]
#     - SAF files for this item
#   * RMID_B02 [item]
#     - SAF files for this item
#   * ...
#
# where
#   ERA_YEAR, FOR4DIGIT_*, RMID_* are all directories within the
#   filesystem, and all files and directories under FOR4DIGIT_*
#   conform to DSpace SAF.
#
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib/libext", File.dirname(__FILE__))

require 'faster_csv'

##############################################################################
# A class for representing an ERA Simple Archive Format (SAF) tree
class EraSafTree
  # Append this string to @era_root_dir_path to give the destination directory
  ERA_ROOT_DIR_PATH_DEST_SUFFIX = '_dest'

  # FasterCSV options for reading CSV file
  FCSV_OPTS = {
    :col_sep => ',',
    :headers => true,
    :header_converters => :symbol,
  }

  attr_reader :era_root_dir_path, :era_root_dir_path_dest, :csv_filenames, :target_items, :plucked_items

  ############################################################################
  # Create this object
  ############################################################################
  def initialize(era_root_dir_path, csv_filenames)
    @era_root_dir_path = era_root_dir_path.sub(/\/$/, '')  # Strip trailing slash
    @era_root_dir_path_dest = @era_root_dir_path + ERA_ROOT_DIR_PATH_DEST_SUFFIX
    verify_src_dest_dir_paths

    @csv_filenames = csv_filenames
    verify_csv_files

    @target_items = []
    @plucked_items = []
    get_items_from_csv_files
    pluck_from_tree
  end

  ############################################################################
  # Verify source and destination directory paths
  ############################################################################
  def verify_src_dest_dir_paths
    unless File.exists?(@era_root_dir_path) && File.directory?(@era_root_dir_path)
      STDERR.puts "Source directory does not exist:\n  '#{@era_root_dir_path}'"
      exit 2
    end
    if File.exists?(@era_root_dir_path_dest)
      STDERR.puts "Destination directory or file already exists:\n  '#{@era_root_dir_path_dest}'"
      exit 3
    end
  end

  ############################################################################
  # Verify CSV files
  ############################################################################
  def verify_csv_files
    if @csv_filenames.empty?
      STDERR.puts "No CSV files have been specified."
      exit 4
    end
    @csv_filenames.each{|f|
      unless File.exists?(f) && File.file?(f)
        STDERR.puts "CSV file does not exist: '#{f}'"
        exit 5
      end
    }
  end

  ############################################################################
  # Read items/RMID from each CSV file
  ############################################################################
  def get_items_from_csv_files
    csv_fmt_str =
      "\n  %s:\n" +
      "    Items (read from file):     %5d%s\n" +
      "    Duplicate items removed:    %5d\n" +
      "    New items (in this file):   %5d\n" +
      "    Total items (in all files): %5d\n"
    puts "\nGathering items from CSV file(s)"
    @csv_filenames.sort.each{|fname|
      items = []
      FasterCSV.foreach(fname, FCSV_OPTS) {|line| items << line[:rmid].chomp }

      items_length_before = items.length
      items.uniq!
      total_items_length_before = @target_items.length
      @target_items = @target_items.concat(items).uniq
      printf csv_fmt_str, File.basename(fname),
        items_length_before, (items_length_before == 0 ? ' **WARNING**' : ''),
        items_length_before - items.length,
        @target_items.length - total_items_length_before, @target_items.length
    }
    @target_items.sort!
    printf "\nTarget items: %s\n\n", @target_items.inspect
  end

  ############################################################################
  # Pluck/remove from the ERA SAF tree any items/RMIDs which were specified in
  # CSV files.
  ############################################################################
  def pluck_from_tree
    # Iterate thru all collections and items in the ERA tree and find any
    # target items. Move such items out of @era_root_dir_path and into
    # an identical hierarchical structure within @era_root_dir_path_dest.

    Dir.glob("#{@era_root_dir_path}/*").sort.each{|coll_dpath|
      next unless File.directory?(coll_dpath)

      Dir.glob("#{coll_dpath}/*").sort.each{|item_dpath|
        next unless File.directory?(item_dpath)
        item = File.basename(item_dpath)
        pluck_item(item_dpath) if @target_items.include?(item)
      }
    }
  end

  ############################################################################
  # Pluck/remove this particular item/RMID from the ERA SAF tree.
  ############################################################################
  def pluck_item(item_dpath_src)
    path_below_root = item_dpath_src.sub(Regexp.new("^#{@era_root_dir_path}/"), '')
    item_dpath_dest = "#{@era_root_dir_path_dest}/#{path_below_root}"
    item_parent_dpath_dest = File.dirname(item_dpath_dest)

    Dir.mkdir(@era_root_dir_path_dest) unless File.exists?(@era_root_dir_path_dest)
    Dir.mkdir(item_parent_dpath_dest) unless File.exists?(item_parent_dpath_dest)
    puts "Moving #{item_dpath_src}\n    to #{item_dpath_dest}"
    File.rename(item_dpath_src, item_dpath_dest)
    @plucked_items << item_dpath_src
  end

  ############################################################################
  # Report re plucked items/RMIDs
  ############################################################################
  def report_plucked_items
    printf "\nNumber of plucked items:  %d\n", @plucked_items.length

    puts "\nTarget items plucked out of directory #{File.basename(@era_root_dir_path)}:"
    @plucked_items.each{|d| puts "  #{File.basename(d)}"}
  end

  ############################################################################
  # Verify the command line arguments
  ############################################################################
  def self.verify_command_line_args
    if ARGV.length < 2 || ARGV.include?('-h') || ARGV.include?('--help')
      STDERR.puts <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0} ERA_ROOT_DIR_PATH CSVFILE1 CSVFILE2...
		  where
		    ERA_ROOT_DIR_PATH is the root of a directory tree
		    containing multiple DSpace collections which conform to
		    the Simple Archive Format (SAF).

		    CSVFILE1, CSVFILE2, etc are CSV files containing column
		    header line "RMID,FOR4D_Owner,FOR4D_Others" and the
		    RMID column is populated with RMIDs to be removed
		    (plucked) from the ERA_ROOT_DIR_PATH tree (and moved into
		    the ERA_ROOT_DIR_PATH#{ERA_ROOT_DIR_PATH_DEST_SUFFIX} tree).
		Note:
		  Item names within each collection are expected to be
		  approx 10-digit RMIDs.

      MSG_COMMAND_LINE_ARGS
      exit 1
    end
  end

  ############################################################################
  # The main method for this class
  ############################################################################
  def self.main
    verify_command_line_args
    root_dir = ARGV.shift

    STDERR.puts "Plucking CSV-specified items from ERA-year before import into DSpace"
    STDERR.puts "--------------------------------------------------------------------"
    STDERR.puts "ERA root directory: #{root_dir}"
    era_tree = EraSafTree.new(root_dir, ARGV)
    era_tree.report_plucked_items
  end
end

##############################################################################
# Main
##############################################################################
EraSafTree.main
exit 0

