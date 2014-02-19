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

  # This class assumes the XML 'name' element:
  # - is mandatory (hence it does not appear in this list) and
  # - its value is unique.
  # The XML elements in this list are optional for a Collection.
  OPTIONAL_ELEMENTS = %w{ description intro copyright sidebar license provenance }

  attr :name

  ############################################################################
  # Creates a Collection object.
  #
  # Invocation exmaple 1:
  #   c = Collection.new(
  #     'My collection name',			# Mandatory XML element
  #     'description' => 'My description',	# Optional XML element
  #     'intro'       => 'My introduction'	# Optional XML element
  #   )
  #
  # Invocation exmaple 2:
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
        exit(2)
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

