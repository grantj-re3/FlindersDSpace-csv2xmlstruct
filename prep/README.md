Preparation work for importing items into new structure
=======================================================

Description
-----------

Prior to importing ERA 2012 items we are interested to know what
ERA 2010 items already exist (as some items will overlap).

The scripts below extract all ERA 2010 research publication items from DSpace:
- hdl_rmis_ResearchPub-old.sh
- hdl_rmis_ResearchPub.sh

These scripts extract other research publication items from DSpace:
- hdl_rmis_ResearchPubNhmrc-old.sh
- hdl_rmis_ResearchPubNhmrc.sh

The pairs of scripts above give identical results (but the older
scripts are more complicated as I was not aware of handle.resource_type_id
at the time).

Research Publications hierarchy
-------------------------------

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

The resource_type_id column
---------------------------
It appears that the resource_type_id column from the handle table can be
used to extract handle info for items, collections and communities by:
- matching the id of the appropriate table with the resource_id in the handle table
- specifying the correct resource_type_id value

The resource_type_id do not seem to be defined in the database or documentation,
but are defined in the source code at URL
https://svn.duraspace.org/dspace/dspace/trunk/dspace-api/src/main/java/org/dspace/core/Constants.java
The values are:
- BITSTREAM = 0
- BUNDLE = 1
- ITEM = 2
- COLLECTION = 3
- COMMUNITY = 4
- SITE = 5
- GROUP = 6
- EPERSON = 7

