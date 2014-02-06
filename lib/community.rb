#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++ 

require 'xmlsimple'
require 'faster_csv'
require 'collection'

##############################################################################
# A class to represent a DSpace community
class Community

  # Lookup table from ERA cluster-abreviations to cluster-descriptions
  CLUSTER_ABBREVIATION2DESCRIPTION = {
    'PCE' => 'Cluster 1. Physical, Chemical and Earth Sciences',
    'HCA' => 'Cluster 2. Humanities and Creative Arts',
    'EE'  => 'Cluster 3. Engineering and Environmental Sciences',
    'EHS' => 'Cluster 4. Education and Human Society',
    'EC'  => 'Cluster 5. Economics and Commerce',
    'MIC' => 'Cluster 6. Mathematical, Information and Computing Sciences',
    'BB'  => 'Cluster 7. Biological and Biotechnological Sciences',
    'MHS' => 'Cluster 8. Medical and Health Sciences',
  }

  # This class assumes the XML 'name' element:
  # - is mandatory (hence it does not appear in this list) and
  # - its value is unique.
  #
  # The XML elements in this list are optional for a Community.
  OPTIONAL_ELEMENTS = %w{ description intro copyright sidebar }

  # Populate all sub-communities with the optional XML elements
  # given below. Note that 'name' is a mandatory XML element
  # and must not appear in this hash.
  SUB_COMMUNITY_XML_ELEMENTS = {
=begin
    'description' => 'Sub-community description',
    'intro'       => 'Sub-community introduction',
    'copyright'   => 'Sub-community copyright text',
    'sidebar'     => 'Sub-community sidebar text'
=end
  }

  # Populate all collections with the optional XML elements
  # given below. Note that 'name' is a mandatory XML element
  # and must not appear in this hash.
  COLLECTION_XML_ELEMENTS = {
=begin
    'description' => 'Collection desc',
    'intro'       => 'Collection intro',
    'copyright'   => 'Collection copyrt',
    'sidebar'     => 'Collection s/bar',
    'license'     => 'Collection lic',
    'provenance'  => 'Collection prov'
=end
  }

  attr_reader :name, :child_comms, :child_colls

  ############################################################################
  # Creates a Community object.
  #
  # Invocation exmaple 1:
  #   c = Community.new(
  #     'My community name',			# Mandatory XML element
  #     'description' => 'My description',	# Optional XML element
  #     'intro'       => 'My introduction'	# Optional XML element
  #   )
  #
  # Invocation exmaple 2:
  #   optional_elements = {
  #     'description' => 'My description',
  #     'intro'       => 'My introduction'
  #   }
  #   c = Community.new('My community name', optional_elements)
  def initialize(name, optional_xml_elements={})
    @name = name		# String
    @child_comms = []		# List of Community objects
    @child_colls = []		# List of Collection objects

    @opts = optional_xml_elements
    @opts.each_key{|k|
      unless OPTIONAL_ELEMENTS.include?(k)
        STDERR.puts "ERROR: XML element <#{k}> is not permitted as part of a #{self.class} in the object: #{inspect_more}"
        exit(2)
      end
    }
  end

  ############################################################################
  # Under this community, this method loads a list of sub-communities
  # and collections belonging to those sub-communities from a CSV file.
  def load_csv(fname, faster_csv_options={})
    opts = {
      :col_sep => ',',
      # It is not advisible to override the values below with those
      # from faster_csv_options (as this method assumes these values)
      :headers => true,
      :header_converters => :symbol,
    }.merge!(faster_csv_options)

    count = 0
    FasterCSV.foreach(fname, opts) {|line|
      count += 1
      puts "\n#{count} <<#{line.to_s.chomp}>>" if MDEBUG.include?(__method__)
      next if skip_csv_line?(line)

      # Get and/or append the community derived from this CSV line
      # under THIS community object.
      comm_name = community_name(line, count)
      comm = self.get_community_with_name?(comm_name)	# Duplicate names are not permitted
      unless comm
        comm = Community.new(comm_name, SUB_COMMUNITY_XML_ELEMENTS)
        self.append_community(comm)
      end

      # Get and/or append the collection derived from this CSV line under
      # the ABOVE community object, comm.
      coll_name = collection_name(line, count)
      coll = comm.get_collection_with_name?(coll_name)	# Duplicate names are not permitted
      unless coll
        coll = Collection.new(coll_name, COLLECTION_XML_ELEMENTS)
        comm.append_collection(coll)
      end
    }
  end

  ############################################################################
  # *_Customise_* this method:
  # Returns true to skip processing of csv_line. You can customise this method
  # to return true in your choice of conditions. Eg. to never skip processing
  # of any CSV line, replace the body of this method with: false
  def skip_csv_line?(csv_line)
    csv_line[:for_code].length == 2	# Skip 2 digit FOR codes
    #false				# Uncomment this line to process all CSV lines
  end

  ############################################################################
  # *_Customise_* this method:
  # Returns community name for this CSV line. You can customise this method
  # to return the name of your choice.
  def community_name(csv_line, csv_line_count=nil)
    comm_name = CLUSTER_ABBREVIATION2DESCRIPTION[ csv_line[:cluster_abbrev] ]	# Full cluster description
    unless comm_name
      STDERR.puts "Method: #{__method__}"
      STDERR.puts "ERROR:  Lookup for cluster code '#{csv_line[:cluster_abbrev]}' not found. See line:"
      STDERR.printf "  %s%s\n", (csv_line_count ? "[#{csv_line_count}] " : ''), csv_line.to_s.chomp
      exit(1)
    end
    comm_name
  end

  ############################################################################
  # *_Customise_* this method:
  # Returns collection name for this CSV line. You can customise this method
  # to return the name of your choice.
  def collection_name(csv_line, csv_line_count=nil)
    "#{csv_line[:for_code]} - #{csv_line[:for_title]}"	# FOR code + FOR title
  end

  ############################################################################
  # Appends a community object to the list of child-communities
  def append_community(comm)
    @child_comms << comm
  end

  ############################################################################
  # Appends a collection object to the list of child-collections
  def append_collection(coll)
    @child_colls << coll
  end

  ############################################################################
  # Returns the first community object from the list of child-communities
  # having a name matching the specified argument. Returns nil if there
  # is no matching name.
  def get_community_with_name?(name)
    @child_comms.each{|c| return c if c.name == name}
    nil
  end

  ############################################################################
  # Returns the first collection object from the list of child-collections
  # having a name matching the specified argument. Returns nil if there
  # is no matching name.
  def get_collection_with_name?(name)
    @child_colls.each{|c| return c if c.name == name}
    nil
  end

  ############################################################################
  # A method which returns a hash representing
  # this community object in a format which is compatible
  # with the XmlSimple class.
  #
  # From outside the class, invoke this method instead of
  # struct_hash().
  def top_struct_hash
    {
      'community' => struct_hash
    }
  end

  ############################################################################
  # A recursive helper-method which returns a hash representing
  # this community object in a format which is compatible
  # with the XmlSimple class. The method is recursive
  # because this community may itself contain other
  # communities.
  #
  # This helper-method is not expected to be invoked externally
  # because it omits the outer 'community' hash-key representing
  # the top-level <community> XML element. Hence
  # from outside the class, invoke top_struct_hash() instead.
  def struct_hash
    struct = {
      'name' => @name,
    }.merge!(@opts)

    struct['community'] = []
    @child_comms.each{|c|
      struct['community'] << c.struct_hash
    }

    struct['collection'] = []
    @child_colls.each{|c|
      struct['collection'] << c.struct_hash
    }
    struct
  end

  ############################################################################
  # A method to convert this community object (including
  # all communities and collections contained in it) into
  # (DSpace 'structure-builder' compatible) XML.
  def to_xml(xmlsimple_opts={})
    opts = {
      'AttrPrefix' => true,
      'rootname' => 'import_structure',
    }.merge!(xmlsimple_opts)
    XmlSimple.xml_out(top_struct_hash, opts)
  end

  ############################################################################
  # Convert this object to a string
  def to_s
    @name
  end

  ############################################################################
  # Inspect this object
  #--
  # FIXME: This output is difficult to read. It would be
  # better to display the community tree-structure using
  # indentation.
  def inspect
    "\n<<#{self.class}::#{@name}>>;\n  #{@name}::Comms: #{@child_comms.inspect};\n  #{@name}::Colls: #{@child_colls.inspect} "
  end

  ############################################################################
  # Inspect all the details (but without showing child
  # communities and collections)
  def inspect_more_without_children
    "\n<<#{self.class}::#{@name}>>;\n  #{@opts.inspect}"
  end

  ############################################################################
  alias inspect_more  inspect_more_without_children
end

