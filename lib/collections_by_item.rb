#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++

require 'dspace_utils'
require 'faster_csv'
require 'object_extra'

##############################################################################
# A class for representing and processing a DSpace collection list per item
##############################################################################
class CollectionsByItem
  include Enumerable
  include DSpaceUtils

  MANDATORY_CSV_IN_FIELDS = [:item_hdl, :c_owner_hdl]
  CSV_IN_FIELDS = MANDATORY_CSV_IN_FIELDS + [:c_others_hdl]

  CSV_OUT_FIELDS = [:item_hdl, :col_hdls]
  EXTRA_CSV_OUT_FIELDS = [:rmid, :item_name, :col_names]

  CSV_DELIMITER = ','
  CSV_QUOTE = '"'

  # FasterCSV options for reading CSV file
  FCSV_OPTS = {
    :col_sep => CSV_DELIMITER,
    :headers => true,
    :header_converters => :symbol,
  }
  # For debugging only: Use handle to lookup additional info in the database
  @@will_lookup_by_handle = false	# Assume no database access is required
  @@dbresources = nil

  attr_accessor :era_year_csv, :collections, :label

  ############################################################################
  # Create this object
  ############################################################################
  def initialize(era_year_csv, label=nil)
    @era_year_csv = era_year_csv
    verify_era_year_csv
    @label = label ? label : File.basename(era_year_csv)
    @collections = {}
  end

  ############################################################################
  # Verify @era_year_csv. ERA reporting-year CSV filename is permitted
  # to be either nil or a valid file.
  ############################################################################
  def verify_era_year_csv
    return unless @era_year_csv		# CSV filename is nil - ok
    unless File.file?(@era_year_csv)
      STDERR.puts "ERROR: File not found '#{@era_year_csv}'"
      exit 2
    end
  end

  ############################################################################
  # Compare objects using their (ERA reporting year) CSV filename
  ############################################################################
  def <=>(other)
    self.era_year_csv <=> other.era_year_csv
  end

  ############################################################################
  # Load items and corresponding collections from the specified CSV file
  ############################################################################
  def load_csv
    line_num = 1		# Count all lines. Assume header on first line
    FasterCSV.foreach(@era_year_csv, FCSV_OPTS) {|line|
      line_num += 1
      next if line.to_s.chomp.empty?

      MANDATORY_CSV_IN_FIELDS.each{|field|
        unless line[field]
          STDERR.printf "ERROR: Mandatory field '%s' is empty in file '%s' in line:\n", field.to_s, @era_year_csv
          STDERR.printf "[Line %d] %s\n", line_num, line.to_s.chomp
          exit 3
        end
      }
      if @collections.has_key?(line[:item_hdl])
        STDERR.printf "ERROR: Item-handle '%s' has been repeated in file '%s'\n", line[:item_hdl], @era_year_csv
        exit 4
      end
      @collections[ line[:item_hdl] ] = [ line[:c_owner_hdl] ]	# Mandatory owning collection
      if line[:c_others_hdl]					# Optional other collections
        line[:c_others_hdl].split(VALUE_DELIMITER).each{|c_hdl|
          @collections[ line[:item_hdl] ] << c_hdl
        }
      end
    }
    verify_collections
  end

  ############################################################################
  # Load items and corresponding collections from the specified hash
  ############################################################################
  def load_collections_hash(collections_by_item)
    @collections = collections_by_item
    verify_collections
  end

  ############################################################################
  # Verify @collections
  ############################################################################
  def verify_collections
    @collections.sort.each{|itemh,colhdls|
      unless colhdls.length == colhdls.uniq.length
        STDERR.printf "ERROR: Item %s is mapped to the same collection more than once\n", itemh
        STDERR.printf "Check all ERA reporting-year CSV files"
        exit 5
      end
    }
  end

  ############################################################################
  # Represent as string (CSV version)
  ############################################################################
  def to_csv
    fields = CSV_OUT_FIELDS
    fields += EXTRA_CSV_OUT_FIELDS if @@will_lookup_by_handle

    header_line = fields.inject([]){|a,f| a << f.to_s}
    lines = [ header_line.join(CSV_DELIMITER) ]

    @collections.sort.each{|item_hdl, col_hdls|
      extra_fields = unless @@will_lookup_by_handle
        nil
      else
        @@dbresources.extra_csv_fields(item_hdl, col_hdls, CSV_DELIMITER, CSV_QUOTE)
      end
      lines << "#{CSV_QUOTE}#{item_hdl}#{CSV_QUOTE}#{CSV_DELIMITER}#{CSV_QUOTE}#{col_hdls.join(VALUE_DELIMITER)}#{CSV_QUOTE}#{extra_fields}"
    }
    lines.join(NEWLINE)
  end

  ############################################################################
  # Represent as string with additional debug information
  ############################################################################
  def to_s_debug
    "#{self.class} label: #{@label};  ERA year CSV file: #{@era_year_csv}\n#{to_csv}"
  end

  ############################################################################
  # Represent as string (summarised version)
  ############################################################################
  def to_s_summary
    sep = "\n  "
    elems = @collections.sort.inject([]){|a,(itemh,colhdls)| a << "#{itemh}(#{colhdls.length})"}
    "#{self.class} label: #{@label};  ERA year CSV file: #{@era_year_csv}#{sep}#{elems.join(sep)}"
  end

  ############################################################################
  # Merge this (target) object with the object representing all previous
  # ERA reporting years. Note that the target collection-list is
  # represented by self.
  ############################################################################
  def merge(prev_collection_list)
    p = prev_collection_list
    items_to_process = gather_items_to_be_processed(p)
    collections_by_item = gather_collections_for_each_item(p, items_to_process)

    label = "Merged(#{@label},#{p ? p.label : 'nil'})"
    merged_collection_list = self.class.new(nil, label)
    merged_collection_list.load_collections_hash(collections_by_item)
    merged_collection_list
  end

  ############################################################################
  # Return an object which consists of a list comprising collections
  # which are in 'self' provided they are not in 'other'.
  ############################################################################
  def exclude(other)
    excluded_collection_list = self.deep_copy
    excluded_collection_list.label = "ExcludeFrom(#{@label},#{other.label})"
    excluded_collection_list.era_year_csv =  nil

    item_hdls = @collections.keys - other.collections.keys
    excluded_collection_list.collections.delete_if{|itemh, chhdls| !item_hdls.include?(itemh)}
    excluded_collection_list
  end

  ############################################################################
  # Invoke this method to setup lookup-by-handle of item and collection
  # information. Database access is not needed (and hence does not need
  # to be configured) unless this method is called. Under the hood, this
  # method creates a database connection, which should later be closed
  # with end_lookup_by_handle().
  ############################################################################
  def self.begin_lookup_by_handle
    @@will_lookup_by_handle = true

    require 'resources4bmet_csv'
    @@dbresources = Resources4BmetCsv.new
  end

  ############################################################################
  # Invoke this method to close down lookup-by-handle of item and collection
  # information. Under the hood, this method closes the database connection
  # opened by begin_lookup_by_handle() if previously opened.
  ############################################################################
  def self.end_lookup_by_handle
    @@will_lookup_by_handle = false
    begin
      @@dbresources.close
    rescue NoMethodError
      # Ignore exception if @@dbresources is nil (DB connection was not open)
    ensure
      @@dbresources =  nil
    end
  end

  private

  ############################################################################
  # Create a list of items to be processed. Note that the target
  # collection-list is represented by self.
  #
  # Store the item for processing if:
  # - the item appears two or more times in the target ERA reporting
  #   year and zero or more times in previous ERA reporting years, or
  # - the item appears once in the target ERA reporting year and
  #   one or more times in previous ERA reporting years
  ############################################################################
  def gather_items_to_be_processed(prev_collection_list)
    # A list of items which belong to multiple collections, and at least
    # one of those collections is in the target ERA reporting year
    items_to_process = []
    p = prev_collection_list
    @collections.sort.each{|itemh, colhdls|
      if colhdls.length > 1 ||
        colhdls.length == 1 && p && p.collections[itemh] && p.collections[itemh].length > 0
          items_to_process << itemh
      end
    }
    items_to_process
  end

  ############################################################################
  # Gather the list of collections for each item which is to be processed.
  # Note that the target collection-list is represented by self.
  #
  # The owning collection shall be first in the list for each item. The
  # owning collection shall be determined as follows.
  # - It will be assumed that both the target and previous ERA reporting
  #   year collection-lists shall list the owning collection first in its
  #   collection-list for each item.
  # - The target ERA reporting year collection-list shall be processed
  #   after the previous ERA reporting year collection-list. Eg.
  #   era2010_and_era2012.csv, era2015target.csv.
  # - The first (ie. oldest reporting-year) CSV file shall be assumed to
  #   contain the owning collection as the first in its collection list
  #   for each item.
  ############################################################################
  def gather_collections_for_each_item(prev_collection_list, items_to_process)
    all_col_lists = prev_collection_list ? [prev_collection_list, self] : [self]
    collections_by_item = {}
    items_to_process.each{|itemh|
      collections_by_item[itemh] = []
      all_col_lists.each{|colhdls|
        collections_by_item[itemh] += colhdls.collections[itemh] if colhdls.collections[itemh]
      }
    }
    collections_by_item
  end

  public

  alias to_s to_csv
end

