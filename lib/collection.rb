#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 

require 'object_extra'
require 'community'

##############################################################################
# A class to represent a DSpace collection
class Collection
  ERA_YEAR = Community::ERA_YEAR

  # This class assumes the XML 'name' element:
  # - is mandatory (hence it does not appear in this list) and
  # - its value is unique.
  # The XML elements in this list are optional for a Collection.
  OPTIONAL_ELEMENTS = %w{ description intro copyright sidebar license provenance }

  # Populate all collections with the optional XML elements
  # given below. Note that 'name' is a mandatory XML element
  # and must not appear in this hash.
  XML_ELEMENTS = {
    'description' => "Flinders' research in {{CSV_FIELD_for_title}}, as reported for ERA #{ERA_YEAR}.",
    'intro'       => "<p>This collection contains Flinders' research in {{CSV_FIELD_for_title}}, as reported for ERA #{ERA_YEAR}.</p>
<p>Where copyright and other restrictions allow, full text content is available.</p>",
=begin
    'copyright'   => 'Collection copyrt',
    'sidebar'     => 'Collection s/bar',
    'license'     => 'Collection lic',
    'provenance'  => 'Collection prov'
=end
  }

  # Exit codes for errors
  ERROR_BASE = 16
  ERROR_XML_ELEMENT_NAME		= ERROR_BASE + 1

  attr :name

  ############################################################################
  # Creates a Collection object.
  #
  # Invocation exmaple:
  #   optional_elements = {
  #     'description' => 'My description',
  #     'intro'       => 'My introduction'
  #   }
  #   c = Collection.new('My collection name', optional_elements)
  def initialize(name, optional_xml_elements={}, csv_fields={})
    @name = name
    @opts = optional_xml_elements
    @opts.each_key{|k|
      unless OPTIONAL_ELEMENTS.include?(k)
        STDERR.puts "ERROR: XML element <#{k}> is not permitted as part of a #{self.class} in the object: #{inspect_more}"
        exit(ERROR_XML_ELEMENT_NAME)
      end
    }
    @csv_fields = csv_fields
    replace_token_in_optional_xml_elements
  end

  ############################################################################
  # If any values in the @opts hash contain tokens, this method replaces
  # such tokens with the corresponding replacement string. ie. This method
  # updates @opts.
  def replace_token_in_optional_xml_elements
    return if @opts.empty? || @csv_fields.empty?

    @opts = @opts.deep_copy
    @opts.each_value{|str|
      Community.replace_token_in_string(str, @csv_fields)
    }
  end

  ############################################################################
  # A method which returns a hash representing this
  # collection object in a format which is compatible
  # with the XmlSimple class.
  def struct_hash
    {
      'name' => @name,
    }.merge!(@opts)
  end

  ############################################################################
  # Convert this object to a string
  def to_s
    @name
  end

  ############################################################################
  # Inspect this object
  def inspect
    "#{self.class}::#{@name}"
  end

  ############################################################################
  # Inspect more of this object
  def inspect_more
    "\n<<#{self.class}::#{@name}>>;\n  #{@opts.inspect}"
  end

end

