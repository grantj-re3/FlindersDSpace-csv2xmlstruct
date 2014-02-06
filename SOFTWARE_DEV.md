Software development documentation for FlindersDSpace-csv2xmlstruct
===================================================================

Data flow
---------

* ERA_2012_DisciplineMatrix4DSpace_v0.1.csv ->
* [csv2xmlstruct_wrap.sh] -> struct.xml ->
* [dspace structure-builder] -> DSpace structure (top level community) ->
* [dspace community-filiator] -> DSpace structure (sub-community)

where
* the flow is represented by an arrow ie. ->
* the text in square brackets represents a process or program
* the text not within square brackets represents the state of the data


Algorithm
---------

- Create the top level community
- Populate the top level community with structure defined in CSV file
  as follows:
  * The (eight) ERA clusters become DSpace sub-communities
  * Each FoR code/title associated with a given ERA cluster becomes a
    DSpace collection under the appropriate (ERA cluster) sub-community
- Convert the structure into XML format as follows:
  * Convert the top-level-community/sub-community/collection object
    structure into a nested hash (compatible with the XmlSimple class)
  * Use XmlSimple to convert the hash into XML


Files
-----

bin/csv2xmlstruct_wrap.sh
- Top level shell wrapper script for bin/csv2xmlstruct.rb.
- It is expected that the user will always run the program via this script.

bin/csv2xmlstruct.rb
- Top level ruby script containing main().

lib/collection.rb
- The ruby script defining the DSpace Collection class.
- Collection objects consist of:
  * A name (ie. a mandatory XML element)
  * Other key-value pairs (ie. optional XML elements)

lib/community.rb
- The ruby script defining the DSpace Community class.
- Community objects consist of:
  * A name (ie. a mandatory XML element)
  * Other key-value pairs (ie. optional XML elements)
  * A list of other community objects (ie. sub-communities) contained 
    within this community
  * A list of collection objects contained within this community

etc/ERA_2012_DisciplineMatrix4DSpace_v0.1.csv
- CSV file containing the relevant columns of the ERA 2012 Discipline Matrix.

etc/ERA_2012_DisciplineMatrix4DSpace_v0.1small.csv
- A few lines of the above CSV file used for test purposes.

lib/libext/faster_csv.rb and lib/libext/fastercsv.rb
- http://fastercsv.rubyforge.org
- An externally sourced library for processing CSV files.
- Starting at ruby 1.9, the standard CSV library has been replaced 
  with FasterCSV. Because I am using ruby 1.8.7 I chose to use this
  library.

lib/libext/xmlsimple.rb
- http://xml-simple.rubyforge.org
- An externally sourced library for converting a hash to XML or XML to a hash.

lib/libext/licenses/LICENSE.fastercsv and 
lib/libext/licenses/LICENSE.xmlsimple
- License information for externally sourced libraries.

