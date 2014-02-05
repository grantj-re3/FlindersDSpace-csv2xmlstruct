FlindersDSpace-csv2xmlstruct
============================

Description
-----------

A program which converts some columns from the ERA 2012 Discipline Matrix
spreadsheet (in CSV format) to an XML file suitable for loading into
DSpace 3.x via the "dspace structure-builder" tool.

The "dspace structure-builder" tool creates the structure under a top-level
community, but the community can be moved under some other community using
the "dspace community-filiator" tool.

This provides an automated way of creating the ERA 2012 structure of
sub-communities and collections under those sub-communities to be
populated later with DSpace items.

Assuming future Excellence in Research for Australia (ERA) evaluations
are conducted in a similar manner (ie. with clusters, FoR codes and
FoR titles defined in a spreadsheet) I imagine it would be trivial
to modify this program (or perhaps just the CSV file) to create a
suitable DSpace structure. The *Draft* Discipline Matrix for ERA 2015
(at www.arc.gov.au/xls/Draft%20ERA%202015%20Discipline%20Matrix.xls)
certainly appears to contain the required columns.


CSV file
--------

CSV_PATH is expected to be a file with content which resembles that below
(derived from www.arc.gov.au/xls/era12/ERA_2012_Discipline_Matrix.xls).
"for_code" and "for_title" combinations must not be duplicated for a
given "cluster_abbrev".

```
cluster_abbrev,for_code,for_title
MIC,01,Mathematical Sciences
MIC,0101,Pure Mathematics
...
PCE,02,Physical Sciences
PCE,0201,Astronomical and Space Sciences
PCE,0202,"Atomic, Molecular, Nuclear, Particle and Plasma Physics"
MIC,0102,Applied Mathematics
...
```

This program together with the above CSV file creates a structure like this:
```
ERA 2012 TEST [community]

- Cluster 6. Mathematical, Information and Computing Sciences [sub-community]
  * 0101 - Pure Mathematics [collection]
  * 0102 - Applied Mathematics [collection]

- Cluster 1. Physical, Chemical and Earth Sciences [sub-community]
  * 0201 - Astronomical and Space Sciences [collection]
  * 0202 - Atomic, Molecular, Nuclear, Particle and Plasma Physics [collection]
```

Notes:
- Two-digit FoR codes are omitted by design. They can easily be
  reinstated by updating the method skip_csv_line?() in lib/community.rb.
- DSpace community and collection names can be built differently from CSV
  fields by updating methods community_name() and collection_name()
  respectively in lib/community.rb.
- The ordering of sub-communities and collections within the XML file are
  arbitrary (as they are derived from a Ruby hash) however the hierachy
  is correctly maintained. However because DSpace displays the communities
  and collections at the same level in alphabetic order, the order within
  the XML file (and hence the handle sequence number) is not obvious to
  the user. So I believe this is unlikely to matter at most institutions.
- XML elements within a community or collection are also arbitrary (as
  they are derived from the same Ruby hash). This has no adverse affect
  on the resulting DSpace structure but can make the XML file difficult
  for humans to read.

Example usage
-------------

After installation and configuration, this program can be used as follows.

Create the XML file containing the structure from the CSV file.
```
bin/csv2xmlstruct_wrap.sh > struct.xml
```

Create the DSpace top-level community and structure beneath it as
defined by struct.xml.
```
# This command should be performed by a DSpace administrator
/path/to/dspace structure-builder -f struct.xml -o struct_out.xml -e DSPACE_ADMIN_USER@example.com
```

Assuming you have an existing DSpace community (top-level or not)
named "ERA Publications" (eg. handle 123456789/0) and you wish to
move the "ERA 2012 TEST" community (eg. handle 123456789/1)
underneath it, you can do so with the command:
```
/path/to/dspace community-filiator --set --parent=123456789/0 --child=123456789/1
```

