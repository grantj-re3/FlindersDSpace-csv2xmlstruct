Preparation work for importing items into new structure
=======================================================

It is expected that one of the following scripts shall be used in the workflow.
The one you chose shall depend upon how you wish to find and map exsiting RMIDs
with to (new) target ERA reporting-year RMIDs.

- itemHdl_colHdl_AllPub.sh shows the RMID, item-handle, owner-handle, list of
collection-handles and miscellaneous information for all items.
   * Items which appear in more than one collection are only counted once.
   * Items may be owned by a collection within or outside an ERA reporting-year.
   * Items might be owned by a collection outside ERA and not be mapped to
     an ERA collection, but will still be shown.
- itemHdl_colHdl_ResearchPubEra.sh shows the RMID, item-handle, owner-handle,
  list of collection-handles and miscellaneous information for each item within
  each collection, under each sub-community, under the communities which match
  the specified regex for ERA-year community name and under the named *parent*
  ERA-year community. This deliberately excludes any collections directly
  beneath the named *parent* ERA-year community.
   * Items which appear in more than one collection are only counted once.
   * Items may be owned by a collection within or outside an ERA reporting-year.
   * If an item is owned by a collection outside ERA and is not mapped to an ERA
     collection, then it will not be shown.


Former Research Publications hierarchy
--------------------------------------

Prior to importing ERA 2012 items we are interested to know what
ERA 2010 items already exist (as some items will overlap).

- hdl_rmid_ResearchPubEra.sh extracts all ERA 2010 research publication items
  from DSpace.
- hdl_rmid_ResearchPubNhmrc.sh extracts other research publication items from
  DSpace.
- hdl_collname_Era2012.sh lists Handle vs Collection Name after importing the
  new ERA 2012 structure.

At the time, the "Research Publications" community looked like this:

- Research Publications
  * National Health and Medical Research Council (NHMRC) [collection]
  * 01 - Physical, Chemical and Earth Sciences
    - 0201 - Astronomical and Space Sciences [collection]
    - 0202 - Atomic, Molecular, Nuclear, Particle and Plasma Physics [collection]
    - ...
  * 02 - Humanities and Creative Arts
    - 1201 - Architecture [collection]
    - 1203 - Design Practice and Management [collection]
    - ...
  * 08 - Public and Allied Health and Health Sciences
    - 1104 - Complementary and Alternative Medicine [collection]
    - 1106 - Human Movement and Sports Science [collection]
    - ...

where:
- "Research Publications" is the top level community
- "National Health and Medical Research Council (NHMRC)" is another
  collection (outside the scope of ERA)
- "01 - Physical, Chemical and Earth Sciences", "02 - Humanities and
  Creative Arts", etc are subcommunities representing the 8 ERA 2010 clusters
- "0201 - Astronomical and Space Sciences", "0202 - Atomic, Molecular,
  Nuclear, Particle and Plasma Physics", etc are collections representing
  4-digit Field of Research (FoR) codes corresponding to the cluster.


Other utilities
---------------

- num_files_ResearchPubEra.sh counts the number of files for each item within
  each collection, under each sub-community, under the communities which match
  the specified regex for ERA-year community name and under the named *parent*
  ERA-year community. This deliberately excludes any collections directly
  beneath the named *parent* ERA-year community.
   * Items which appear in more than one collection are only counted once.
   * Items may be owned by a collection within or outside an ERA reporting-year.
- rmidsNotInEra_ResearchPubEra.sh shows the RMID, handle and miscellaneous
  information regarding all items which have an RMID but which are __not__
  owned by (or mapped to) any collection under an ERA year.


The resource_type_id column
---------------------------
It appears that the resource_type_id column from the handle table can be
used to extract handle info for items, collections and communities by:
- matching the id of the appropriate table with the resource_id in the handle table
- specifying the correct resource_type_id value

The resource_type_id values do not seem to be defined in the database or
documentation, but are defined in the source code at URL
https://svn.duraspace.org/dspace/dspace/trunk/dspace-api/src/main/java/org/dspace/core/Constants.java
The values are given in the table below.

resource_type_id | meaning of resource_id
-----------------|--------------------
0                | BITSTREAM
1                | BUNDLE
2                | ITEM
3                | COLLECTION
4                | COMMUNITY
5                | SITE
6                | GROUP
7                | EPERSON


For example, to find handles for particular items, you might use the following
SQL fragment.
```
  collection2item c2i 
  ...
  LEFT OUTER JOIN handle h on (c2i.item_id = h.resource_id and h.resource_type_id = 2)
```

