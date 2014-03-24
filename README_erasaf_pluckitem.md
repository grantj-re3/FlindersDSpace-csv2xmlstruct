erasaf_pluckitem.rb
===================

Description
-----------
_erasaf_check.rb_: Check for duplicate items and other potential issues
in an ERA Simple Archive Format (SAF) tree. This is achieved by
iterating through ERA DSpace Simple Archive Format (SAF) directories
within the tree then showing reports for the following aspects:
- collection and item counts
- unexpected files
- empty collection or item directories
- duplicate item directories

This is not an exhaustive check. Some of the deficiencies are listed
below.
- The presence of dublin_core.xml, contents and associated item
  bitstream files are not checked.
- Although empty collection or item directories may represent a
  problem in some/many scenarios, there are many potential issues
  with non-empty directories. Eg1. Non-empty collection directories
  might contain no item directories but only contain useless files.
  Eg2. Non-empty item directories might be missing dublin_core.xml
  and contents files or the contents file might not match the
  included bitstreams.

_erasaf_pluckitem.rb_: Check if items (ie. RMIDs) from any of the
specified CSV files are found in the specified ERA Simple Archive
Format (SAF) tree.  If so, extract the item by moving it to an
identical hierarchical position in a destination tree (for potential
future processing by the DSpace Batch Metadata Editing Tool, BMET).
The intention is that each CSV file lists the items which already exist
in DSpace from a previous ERA reporting year. Instead of overwriting
such items, we will retain the existing item - hence this application
removes those items from the ERA SAF tree. (A later step will assign
some items to multiple collections since the SAF tools are unable
to do that.)

Example usage
-------------

- Check the ERA SAF tree.
```
erasaf_check.rb /path/to/my/era_tree
```

- Investigate and resolve any issues highlighted by erasaf_check.rb
  appropriately.

- Iterate through the ERA SAF tree, pluck out of that structure any
  items which already exist in DSpace (eg. from a previous ERA
  reporting year).

```
erasaf_pluckitem.rb /path/to/my/era_tree existingRmid2010.csv [ otherRmid.csv ]
```

- Import each SAF collection into DSpace.

```
cd /path/to/my/era_tree
# Test the import
dspace import -a -s EraSafCollectionDir -c HandleOfEraSafCollectionDir -m mapfile -e user@example.com --test
# Perform the import
dspace import -a -s EraSafCollectionDir -c HandleOfEraSafCollectionDir -m mapfile -e user@example.com
```

where:
- EraSafCollectionDir is the collection directory (typically a 4-digit
  FOR code) within the ERA SAF tree
- HandleOfEraSafCollectionDir is the handle of the existing DSpace
  collection (typically a 4-digit FOR code and corresponding description)

