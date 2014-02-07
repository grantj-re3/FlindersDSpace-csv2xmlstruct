#!/usr/bin/ruby
# csv2xmlstruct.rb
#
#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 
##############################################################################

# Add dirs to the library path
$: << "../lib"
$: << "../lib/libext"

require 'community'

# Method-debug: List method-name symbols for which you want to show debug info
MDEBUG = [
  #:load_csv,
]

##############################################################################
# A class which converts some columns from the ERA 2012 Discipline Matrix
# spreadsheet (in CSV format) to an XML file suitable for loading into
# DSpace 3.x via the "dspace structure-builder" tool.
class Csv2XmlStruct

  CSV_PATH = "../etc/ERA_2012_DisciplineMatrix4DSpace_v0.1small.csv"
  CSV_DELIMITER = ','

  TOP_COMMUNITY_NAME = 'ERA 2012 TEST'
  TOP_COMMUNITY_XML_ELEMENTS = {
=begin
      'description' => 'Top community description',
      'intro'       => 'Top community introduction',
      'copyright'   => 'Top community copyright text',
      'sidebar'     => 'Top community sidebar text'
=end
  }


  ############################################################################
  # The main method for this program.
  def self.main
    STDERR.puts "\nXML for DSpace 'structure-builder' Tool"
    STDERR.puts   "---------------------------------------"

    top_community = Community.new(TOP_COMMUNITY_NAME, TOP_COMMUNITY_XML_ELEMENTS)
    top_community.load_csv(CSV_PATH, :col_sep => CSV_DELIMITER)
    puts top_community.to_xml
  end

end

##############################################################################
# Main
##############################################################################
Csv2XmlStruct.main
exit 0

