FlindersDSpace-importERA
========================

## Description
ERA is described at http://www.arc.gov.au/era

This suite of applications allows one to:
- obtain appropriate ERA metadata-only files from your univerity's
  Research Management Information System (MIS)
- create a DSpace community/collection structure for the above metadata
- import the Research MIS metadata into the above DSpace structure (without
  duplicating items imported during previous ERA reporting-years)
- map a new item to more than one new collection and map an existing item
  to more than one new and/or existing collection

## Concepts
- An ERA reporting-year is a year in which a "full round of ERA occurred"
  as described on the above web page. So far, these have been ERA 2010
  and ERA 2012. Preparations are currently under way for ERA 2015.

- The target ERA reporting-year is the reporting-year for which ERA
  metadata are being imported into DSpace. Eg. ERA 2012.

- Previous ERA reporting-years are years which have already been imported
  into DSpace prior to the target ERA reporting-year. Eg. If the target
  ERA reporting-year is ERA 2012, then the only previous ERA reporting-year
  would be ERA 2010.

- A DSpace ERA item corresponds to a metadata record for a research output.
  It has an associated identifier, RMID (ie. Research-MIS ID).

- A DSpace ERA collection corresponds to a 4-digit FOR (Field of Research) code.

- The ERA DSpace structure shall comprise the following hierarchical levels.
  * Optional higher level communities. In our case, one top level community
    called "Research Publications".
  * Below that, a community for each ERA reporting-year. Eg. "ERA 2010" and
    "ERA 2012".
  * Below each ERA reporting-year community, a set of sub-communities. In
    our case, we expect these to be either a representation of ERA clusters
    (eg. as specified by the ERA 2012 Discipline Matrix
    http://www.arc.gov.au/era/era_2012/archive/key_documents_2012.htm) or
    a representation of 2-digit FOR codes.
  * Below each cluster or 2-digit FOR sub-community, a set of 4-digit FOR
    collections. Note that 4-digit FOR collection names are likely to be
    repeated from one ERA reporting-year to the next.
  * Below each collection, one item per research output. The items are
    typically metadata-only but may have bitstreams added manually later.

- An item (research output) may belong to one or more collections (FOR codes)
  for the target ERA reporting-year. These collections shall be specified in
  a CSV file.

- An item (identified by its RMID) for the target ERA reporting-year may
  also have appeared in a previous ERA reporting-year (or elsewhere in a
  DSpace collection which is unrelated to ERA). In order to avoid
  duplication of the item and retain any existing bitstreams or metadata
  edits, the newly sent item (which is part of the target ERA reporting-year)
  shall be *discarded* and the existing DSpace item shall be used.

- An item (research output) may belong to one or more collections (FOR codes)
  for previous ERA reporting-years (or elsewhere in a DSpace collection which
  is unrelated to ERA). These collections shall be extracted from the DSpace
  database and placed into a CSV file.

- Any items in the target ERA reporting-year which exist in more than one
  collection (from target or previous ERA reporting-years or elsewhere in
  another DSpace collection) shall be mapped so that they appear in all the
  existing DSpace collections plus the (new) target ERA reporting-year
  collections.


## Warning

Most of the programs in this repository create DSpace Simple Archive Format
(SAF) or Batch Metadata Editing Tool (BMET) files and directories so are
fairly safe to run on your system. However, please exercise great
caution when:
- running the DSpace structure-builder tool
- importing items into DSpace using SAF (eg. the script created by
  bin/erasaf_mkimport.rb)
- updating items in DSpace using BMET (eg. during phases 2 and 3)
- running programs which can potentially make changes to huge
  numbers of (intended or unintended) files eg. utils/del_lang_field.sh

To use this software, it is assumed you have a good understanding
of the DSpace application, Linux/Unix shell and perhaps a little
understanding of Ruby.

Do not use this software unless you know what you are doing.

**Use this software at your own risk.**

## Workflow

More details regarding many of the applications listed below are given
in README*.md files within this directory.

### :bell:  *Phase 1 - Ingest new items*

### Obtain information from your Research MIS
Obtain the following ERA target reporting-year (eg. ERA 2012) information
from your Research MIS
- RM-format (CSV1) CSV file which specifies an RMID per item plus a
  mapping to all corresponding collections for the ERA target reporting-year.
- Item metadata for research outputs in DSpace Simple Archive Format (SAF).
  * Each 4-digit FOR code will have its own collection. SAF
    collection-level directories must be assigned the same name as the
    collection's 4-digit FOR code.
  * SAF item-level directories must be assigned the same name as the item's
    RMID.
  * SAF item-level dublin_core.xml files must contain an RMID-identifier
    as shown below (and DSpace must be configured to recognise such a
    Dublin Core RMID-identifier via the Metadata Registry).
```
<dcvalue element="identifier" qualifier="rmid" ... >...</dcvalue>
```

Note 1: Even if an RMID (ie. item) must appear against several 4-digit
FOR codes (ie. collections) it must only be defined once within the whole
SAF tree (supplied by the Research MIS system). However, it will ultimately
appear in all corresponding collections due to the RM-format (CSV1) CSV
mapping file discussed above (also supplied by the Research MIS system).

Note 2: This process assumes that the Research MIS system does not
know (or chooses to ignore) which RMIDs already exist within DSpace
and hence supplies _all_ RMIDs for the target ERA reporting-year.
However because this suite of programs is DSpace-aware, aspects
regarding duplication and mapping are dealt with by this workflow.

### bin/csv2xmlstruct.rb
Create a community/collection DSpace structure to hold items for the ERA
target reporting-year (eg. ERA 2012). The structure is written to an XML
file.

Use the DSpace structure-builder tool to convert the XML file into a
community/collection hierarchy as described in the
[Concepts](#concepts) section above. More information is provided
[here](README20_csv2xmlstruct.md).

### prep/itemHdl_colHdl_ResearchPubEra.sh
Extract all RMIDs in all DSpace ERA reporting year trees in
RMID-Only-format, CSV2. (Alternatively, use
prep/itemHdl_colHdl_AllPub.sh to extract all RMIDs in all of
DSpace in RMID-Only-format, CSV2.) You should extract this
data at this point in the workflow before new items are added
for the target year.

If any RMIDs are null, such item records will be grouped
together at the bottom of this file (due to the SQL 'order
by' clause). This workflow has only been used with such
null-RMID item records removed from this CSV file.

### bin/erasaf_check.rb
Perform some checking on the ERA SAF-tree.

### bin/erasaf_pluckitem.rb
If items are present within the ERA target reporting-year SAF directory tree
but already exist within DSpace from previous ERA reporting-years (or
perhaps exist independently of ERA) then this application "plucks" such
items from the SAF tree so that they will not be imported into DSpace
(as discussed in the [Concepts](#concepts) section above).

In order to prepare for phase 3 (Update old items with new field values)
you should create a CSV file containing only items which have been
plucked out of the SAF-tree. After running bin/erasaf_pluckitem.rb (which
creates the file plucked_items_regex.txt) you can do that as below.
```
# Copy the header line from the earlier database extract
head -1 itemHdl_colHdl_ResearchPubEra.csv > itemHdl_colHdl_ResearchPubEra_pluckedout.csv

# Extract the plucked-out lines from the earlier database extract
egrep -f plucked_items_regex.txt itemHdl_colHdl_ResearchPubEra.csv >> itemHdl_colHdl_ResearchPubEra_pluckedout.csv
```

### bin/erasaf_mkimport.rb
DSpace provides a tool to import a single SAF collection into DSpace.
For the target ERA reporting-year, we wish to import over 150
(4-digit FOR) collections into DSpace. This app creates a shell script
which achieves this by invoking the DSpace import command over 150 times.

Run the resulting shell script to import all (non-duplicate/non-plucked)
target ERA reporting-year items into the newly created ERA structure.

### :bell:  *Phase 2 - Map items to multiple collections*

### bin/rmcsv2hdlcsv.rb
This application can only be run after the target ERA reporting-year
items have been imported into DSpace (and hence have been assigned a
handle).

Convert RM-format (CSV1) CSV file from the Research Management Information
System to a Handle-format (CSV3) CSV file so that collections can be
uniquely identified by their handle (even if they have an identical
collection name such as a 4-digit FOR code under some other ERA
reporting-year).

### bin/erabme_multicollections.rb
For any ERA item for the target ERA reporting year (extracted from the
Research MIS) which we have already imported into DSpace (either in the
target or previous reporting years) this application will create a CSV
file which will map the item to all collections to which it belongs.

As input to this application, you should reuse the CSV file created
above (by running prep/itemHdl_colHdl_AllPub.sh or
prep/itemHdl_colHdl_ResearchPubEra.sh). However this time the
application will use the columns specified for Handle-format, CSV3.

The resulting file (in Handle-format, CSV3) is almost identical to a
Batch Metadata Editing Tool (BMET) CSV file except that items are
identified by their handle rather their item ID.

### bin/hdl2item_bmecsv.rb
This application takes the above Handle-format (CSV3) CSV file
and converts the item-handle into an item-id as required for
the BMET CSV format.

Then we can make other minor changes to the CSV file, in particular:
- rename "col_hdls" column to "collection" column for BMET
- remove unwanted columns (leaving only id and collection columns)
```
# Fix CSV columns for BMET
awk -F\" '$4=="col_hdls"{$4="collection"} {printf "%s,%s\n",$2,$4}' hdl2item_bmecsv.csv > bmet.csv

# Apply item mapping into multiple collections via the DSpace BMET
$HOME/dspace/bin/dspace metadata-import -f bmet.csv |tee metadata-import.log
```


### :bell:  *Phase 3 - Update old items with new field values*

### bin/erasaf_updatedbfield.rb

This program processes items which have already been plucked out of the RMIS
SAF-tree because they already exist in the database. (Hence these
items were not included in the SAF import.) The processing involves
updating certain database fields based on newer information in the
RMIS SAF-tree (if applicable).

The functionality of the program is controlled by a command line
switch which can have the value 'add_forgroups' or 'replace_type'.

- 'add_forgroups' switch: This program will compare each item's
  list of dc.subject.forgroup fields in the DSpace database with
  those in the Research MIS data (in the Simple Archive Format
  (SAF) tree specified by PLUCKED_OUT_DIR). If the RMIS data
  for a particular item contains any additional dc.subject.forgroup
  fields, those extra fields will be added to the database (by
  running this script and importing the resulting CSV file using
  the DSpace Batch Metadata Editing Tool).

- 'replace_type' switch: This program will compare each item's
  dc.type field in the DSpace database with that in the Research
  MIS data (in the Simple Archive Format (SAF) tree specified by
  PLUCKED_OUT_DIR). If the two fields are different, the database
  copy of the field will be replaced with the SAF copy (by
  running this script and importing the resulting CSV file using
  the DSpace Batch Metadata Editing Tool). It expects one
  dc.type field per item.


## CSV types used in the above workflow
### CSV1 (RM) format
CSV1 format is only suitable if the target ERA reporting year is
known (otherwise the 4-digit FOR collection might apply to a
collection in any ERA reporting-year). Hence it is suitable for
the target ERA reporting-year so can be extracted directly from
your Research MIS.
```
RMID,FOR4D_Owner,FOR4D_Others
1222333444,0101,0102||0103
1222333555,0104,
```

### CSV2 (RMID-Only) format
```
RMID
1222333444
1222333555
```

### CSV3 (handle) format
CSV3 format is only suitable once a tree structure has been created
for the particular ERA reporting year(s) and items have been ingested
into such structure(s). Before this time, handles for both items and
collections have not been created. Hence this is *unsuitable* for
extraction from your Research MIS.
```
item_hdl,col_owner_hdl,col_others_hdl
123456789/90,123456789/1111,123456789/1112||123456789/1113
123456789/91,123456789/1114,
```

### DSpace BMET CSV format
Consult the DSpace manual for the Batch Metadata Editing Tool CSV format.

### Note
CSV files discussed in the [Workflow](#workflow)
section must contain the columns specified above. However,
the software in this suite (but not DSpace tools) does permit
CSV files to also contain other columns which will be ignored by the
corresponding software. This means that in one of the cases above, the
same CSV data extracted by prep/itemHdl_colHdl_AllPub.sh (or
prep/itemHdl_colHdl_ResearchPubEra.sh) can be used in two places. That
is, previous items which have an RMID can be deemed to satisfy both:
- RMID-Only-format (CSV2), and
- Handle-format (CSV3)

Hence the hybrid CSV2/CSV3 format would look something like:
```
rmid,item_hdl,col_owner_hdl,col_others_hdl
1222333444,123456789/90,123456789/1111,123456789/1112||123456789/1113
1222333555,123456789/91,123456789/1114,
```

## Utilities

### split command

To divide BMET CSV files into units of 1000 lines or less (as recommended
in the DSpace manual) I found the linux/unix 'split' command very useful.
Type 'man split' on your system for help. The method used was:
- remove the CSV header line from the large file
- split into multiple smaller files
- add the CSV header line to every resultant smaller file

### bin/comm2newparent

This tool is not required for the above workflow, however we used it to
move some ERA 2010 (child) communities under a new parent community to
conform to a new structure required by this suite of applications.

### utils/del_lang_field.sh

This tool is not required for the above workflow, however we used it to
delete the dc.language[.*] field within all SAF-tree dublin_core.xml files.
Exercise great caution if you use this script!

### prep/ itemHdl_colHdl_forgroup_ResearchPubEra.sh

This tool is not required for the above workflow, however we used it to
backup ERA 2010 dc.subject.forgroup information (for later verification
that ERA 2010 4-digit FOR codes have a one-to-one correspondance to ERA 2010
4-digit FOR code collections). We used this script rather than the
output of the Batch Metadata Editing Tool export of the ERA 2010
community because it appears BMET will only export items owned by
collections within the community (whereas this script also includes
items owned outside the community but mapped into collections within
the community).

### prep/*.sh

A variety of scripts for extracting useful and (perhaps) interesting
information from the DSpace database.

Each script contains a brief description (assigned to the "descr"
environment variable).

