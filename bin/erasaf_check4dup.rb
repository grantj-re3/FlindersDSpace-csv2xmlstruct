#!/usr/bin/ruby
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
# Check for duplicate items and other potential issues in an ERA
# Simple Archive Format (SAF) tree.
# 
# Iterate through ERA DSpace Simple Archive Format (SAF) directories
# searching for duplicate item directories. Report any which are found.
#
# An ERA SAF tree shall be arranged in the following hierarchy.
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
# - ERA_YEAR, FOR4DIGIT_*, RMID_* are all directories within the
#   filesystem, and
# - all files and directories under FOR4DIGIT_* conform to DSpace SAF
#
##############################################################################

##############################################################################
# A class for representing an ERA Simple Archive Format (SAF) tree.
# Class EraSafTree1 is a representation for phase 1 ie. verification
# (prior to plucking).
class EraSafTree1

  attr_reader :era_root_dir_path, :coll_names, :dup_items, :unexpected_files, :counts

  ############################################################################
  # Create this object
  ############################################################################
  def initialize(era_root_dir_path)
    @era_root_dir_path = era_root_dir_path.sub(/\/$/, '')
    parse_tree
  end

  ############################################################################
  # Report regarding items which appear in more than one collection
  ############################################################################
  def report_duplicate_items
    printf "\n%sThe number of items which exist in more than one collection: %d\n",
      (@dup_items.size > 1 ? '**WARNING** ' : ''), @dup_items.size
    @dup_items.sort.each{|item_name|
      puts "  Item #{item_name} exists in collections: #{@coll_names[item_name].join(', ')}"
    }
  end

  ############################################################################
  # Report regarding unexpected files within the ERA SAF tree
  ############################################################################
  def report_unexpected_files
    printf "\n%sThe number of unexpected files (above item-detail directories): %d\n",
      (@unexpected_files.size > 1 ? '**WARNING** ' : ''), @unexpected_files.size
    @unexpected_files.each{|f| puts "  Unexpected file: #{f}"}
  end

  ############################################################################
  # Report regarding collection and item counts
  ############################################################################
  def report_counters
    puts
    [:collection, :item].each{|type|
      printf   "%sThe number of %s directories: %d\n",
        (counts[type] == 0 ? '**WARNING** ' : ''), type, counts[type]
    }
  end

  private

  ############################################################################
  # Parse the ERA SAF tree and gather interesting info
  ############################################################################
  def parse_tree
    # Iterate thru all collections and items in the ERA tree and remember:
    # - the collection(s) to which each item belongs
    # - any non-dirs at the same level as collection or item dirs
    # - counts of collections and items
    @coll_names = {}
    @unexpected_files = []
    @counts = Hash.new(0)
    Dir.glob("#{@era_root_dir_path}/*").sort.each{|coll_dpath|
      unless File.directory?(coll_dpath)
        @unexpected_files << coll_dpath
        next
      end
      @counts[:collection] += 1

      Dir.glob("#{coll_dpath}/*").sort.each{|item_dpath|
        unless File.directory?(item_dpath)
          @unexpected_files << item_dpath
          next
        end
        @counts[:item] += 1
        item_name = File.basename(item_dpath)

        @coll_names[item_name] = [] unless @coll_names[item_name]
        @coll_names[item_name] << File.basename(coll_dpath)
      }
    }
    # Iterate thru all items and remember which exist in more than 1 collection
    @dup_items = coll_names.inject([]){|a,(item_name, coll_list)| coll_list.size > 1 ? a << item_name : a}
  end

  public

  ############################################################################
  # The main method for this class
  ############################################################################
  def self.main
    verify_command_line_args
    root_dir = ARGV.shift

    STDERR.puts "Searching for duplicate SAF items before import into DSpace ERA-year"
    STDERR.puts "--------------------------------------------------------------------"
    STDERR.puts "ERA root directory: #{root_dir}"

    era_tree = EraSafTree1.new(root_dir)
    era_tree.report_counters
    era_tree.report_unexpected_files
    era_tree.report_duplicate_items
  end

  private

  ############################################################################
  # Verify the command line arguments
  ############################################################################
  def self.verify_command_line_args
    unless ARGV.length == 1 && File.directory?(ARGV[0])
      STDERR.puts <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0} ERA_ROOT_DIR_PATH
		  where ERA_ROOT_DIR_PATH is the root of a directory tree
		  containing multiple DSpace collections which conform to
		  the Simple Archive Format (SAF).

		  Collection names are expected to be 4-digit FOR codes.
		  Item names within each collection are expected to be
		  approx 10-digit RMIDs.

      MSG_COMMAND_LINE_ARGS
      exit 1
    end
  end

end

##############################################################################
# Main
##############################################################################
EraSafTree1.main
exit 0

