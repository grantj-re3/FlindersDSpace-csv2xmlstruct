#!/usr/bin/ruby
# query.rb
# 
# Perform an SQL query/command.
# 
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
#
##############################################################################

# Add dirs to the library path
$: << File.expand_path("../lib", File.dirname(__FILE__))
$: << "#{ENV['HOME']}/.ds/etc"

require 'rubygems'
require 'pg'
require 'pg_extra'
require 'dbc'

##############################################################################
# A class to perform an SQL command
class SqlQuery
  include DbConnection

  ############################################################################
  # Verify the command line arguments.
  def self.verify_command_line_args
    unless ARGV.length == 1
      STDERR.puts "Usage:  #{File.basename $0}  \"SQL_COMMAND\""
      exit 1
    end
  end

  ############################################################################
  # Query the database
  def self.get_query_results(sql)
    begin
      PG::Connection.connect2(DB_CONNECT_INFO){|conn|
        conn.exec(sql) do |result|
          result.each do |row|
            # Is there a better way to show generic output?
            puts row.sort.inspect.gsub(/\[\[|\]\]/, '').gsub(/\], *\[/, '; ')
          end
        end
      }
    rescue Exception => ex
      puts "Error detected in method '#{__method__}'.\n#{ex}"
      exit 2
    end
  end

  ############################################################################
  # The main method for this class.
  def self.main
    verify_command_line_args
    sql = ARGV[0].chomp
    get_query_results(sql)
  end

end

##############################################################################
# Main
##############################################################################
SqlQuery.main
exit 0

