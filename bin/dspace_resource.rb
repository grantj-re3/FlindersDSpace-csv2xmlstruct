#!/usr/bin/ruby
# dspace_resource.rb
#
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
# This file can be used as a library or a command line tool to
# look up a specified handle and return the corresponding resource ID.
# ie. item_id, collection_id or community_id.
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

# Use main() from this file unless already defined
MAIN_CLASS = :DSpaceResource unless defined?(MAIN_CLASS)

require 'rubygems'
require 'pg'
require 'pg_extra'
require 'dbc'

##############################################################################
# A class to represent Handle.net objects used in DSpace.
class DSpaceResource
  include DbConnection

  # This hash shows the relationship between the DSpace handle table's
  # resource_type_id and its type.
  RESOURCE_TYPE_ID_TO_TYPE = {
    2 => :item,
    3 => :collection,
    4 => :community,
  }


  # Exit codes for errors
  ERROR_BASE = 32
  ERROR_RESOURCE_NOT_FOUND	= ERROR_BASE + 1
  ERROR_BAD_RESOURCE_TYPE	= ERROR_BASE + 2
  ERROR_BAD_RESOURCE_ID		= ERROR_BASE + 3
  ERROR_COMMAND_LINE_ARGS	= ERROR_BASE + 4

  attr_reader :handle_string, :resource_type, :resource_id

  ############################################################################
  # Create a new object. The handle string represents a Handle.net
  # prefix and suffix. Eg. "123456789/11" where "123456789" is the prefix.
  # The handle is not a URL ie. not http://hdl.handle.net/123456789/11.
  #
  # The expected_resource_type argument can be nil or one of the symbols
  # listed in RESOURCE_TYPE_ID_TO_TYPE. If the value is not nil, we
  # perform very strict checking of the @resource_type and @resource_id.
  def initialize(handle_string, expected_resource_type=nil)
    @handle_string = handle_string
    @resource_type = nil
    @resource_id = nil
    get_resource_info
    if expected_resource_type		# Perform strict checking
      if @resource_type == nil && @resource_id == nil
        STDERR.puts <<-MSG_RESOURCE_NOT_FOUND.gsub(/^\t*/, '')
		ERROR: Unable to find a matching handle within the database.
		  #{self.to_s}
        MSG_RESOURCE_NOT_FOUND
        exit(ERROR_RESOURCE_NOT_FOUND)
      end
      unless @resource_type == expected_resource_type
        STDERR.puts <<-MSG_BAD_RESOURCE_TYPE.gsub(/^\t*/, '')
		ERROR: Unexpected resource type!
		  Expected type='#{expected_resource_type}';  Actual type='#{@resource_type}'
		  #{self.to_s}
        MSG_BAD_RESOURCE_TYPE
        exit(ERROR_BAD_RESOURCE_TYPE)
      end
      unless @resource_id
        STDERR.puts <<-MSG_BAD_RESOURCE_ID.gsub(/^\t*/, '')
		ERROR: Resource ID does not exist. (Perhaps it has been deleted?)
		  #{self.to_s}
        MSG_BAD_RESOURCE_ID
        exit(ERROR_BAD_RESOURCE_ID)
      end
    end
  end

  ############################################################################
  # Query the database to determine @resource_type and @resource_id.
  def get_resource_info
    sql = "select resource_type_id, resource_id from handle where handle = '#{@handle_string}'"
    PG::Connection.connect2(DB_CONNECT_INFO){|conn|
      conn.exec(sql) do |result|
        result.each do |row|
          @resource_id = row['resource_id'].kind_of?(String) ?  row['resource_id'].to_i : nil
          @resource_type = RESOURCE_TYPE_ID_TO_TYPE[ row['resource_type_id'].to_i ]
          return
        end
      end
    }
  end

  ############################################################################
  # Represent object as a string.
  def to_s
    result = if @resource_type
      # @resource_id.inspect displays 'nil' when the DB column is nil
      "#{@resource_type}_id = #{@resource_id.inspect}"
    else
      "No resource found"
    end
    "#{result} (for handle '#{@handle_string}')"
  end

  ############################################################################
  # Verify the command line arguments.
  def self.verify_command_line_args
    unless ARGV.length == 1 && ARGV[0].count('/') == 1
      STDERR.puts <<-MSG_COMMAND_LINE_ARGS.gsub(/^\t*/, '')
		Usage:  #{File.basename $0}  HANDLE_STRING
		  where HANDLE_STRING is PREFIX/SUFFIX; Eg. 123456789/1111

		This application finds the DSpace resource ID based on the specified handle.
		The resource can be an item, collection or community.
		
      MSG_COMMAND_LINE_ARGS
      exit(ERROR_COMMAND_LINE_ARGS)
    end
  end

  ############################################################################
  # A test method for this class.
  def self.test1
    handle_strings = [
      # item, collection & community
      ["123456789/5235", :item],
      ["123456789/5057", :collection],
      ["123456789/5055", :community],
      ["123456789/4774", :collection],	# Collection which no longer has a resource_id
      ["111112222/5235", :item],	# Invalid handle for our DB
    ]
    puts "Test: Lookup list of handles to obtain their resource IDs"
    puts "---------------------------------------------------------"
    handle_strings.each{|hs,type|
      #h = DSpaceResource.new(hs, type)
      h = DSpaceResource.new(hs)
      puts h
    }
  end

  ############################################################################
  # The main method for this class.
  def self.main
    verify_command_line_args
    h = DSpaceResource.new( ARGV[0].chomp )
    puts h
  end

end

##############################################################################
# Main
##############################################################################
if MAIN_CLASS == :DSpaceResource
  #DSpaceResource.test1
  DSpaceResource.main
  exit(0)
end

