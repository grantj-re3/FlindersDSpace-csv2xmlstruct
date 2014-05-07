#!/bin/sh
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
user=$USER	# Database user: Assume same name as the Unix user
db=dspace	# Database name
era_comm_name="ERA 2010"	# The ERA community name (under the 'Research Publications' community)

# I've deliberately said:
#   where parent_comm_id = (... where name='$era_comm_name')
#
# rather than:
#   where parent_comm_id in (... where name='$era_comm_name')
#
# so that if another community appears with an identical name we will get
# a syntax error and investigate if this query needs to be refined.
sql="
select
  c2i.item_id,
  mv.text_value rmid,
  'http://hdl.handle.net/' || h.handle handle,
  com2c.community_id comm_id,
  c2i.collection_id c_id,
  (select name from community where community_id=com2c.community_id) community_name,
  (select name from collection where collection_id=c2i.collection_id) collection_name
from
  item,
  community2collection com2c,
  collection2item c2i 
    LEFT OUTER JOIN metadatavalue mv on (c2i.item_id=mv.item_id and mv.metadata_field_id=
      (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid')
    )
    LEFT OUTER JOIN handle h on (c2i.item_id = h.resource_id and h.resource_type_id = 2)
where
  com2c.community_id in
    (select child_comm_id from community2community where parent_comm_id =
      (select community_id from community where name='$era_comm_name')
    )
  and c2i.collection_id=com2c.collection_id
  and c2i.item_id not in (select item_id from item where withdrawn=true)
  and item.item_id = c2i.item_id
  and item.owning_collection = c2i.collection_id
order by rmid
"

query="copy (
$sql
)
to stdout
with
  delimiter '|'
  csv
    header
    force quote community_name, collection_name
"

descr="List all items within each collection under each sub-community under the
'$era_comm_name' community (ie. deliberately exclude any collections directly
beneath the '$era_comm_name' community).

NOTES:

1) Because some items appear in more than one collection (eg. item_id 13012;
http://dspace.flinders.edu.au/jspui/handle/2328/12895) but an item can only
have 1 collection-owner, this query only counts items 'owned by' the collection.
This prevents listing the same item more than once. (I have previously checked
that each item under each collection under each sub-community under the
'$era_comm_name' community is owned by a collection under 'Research Publications'.)

2) Items 26359,26360 have no RMID (so I presume they did not originate from RM).

3) It seems that DSpace sums items in an unexpected way. Eg.
For '08 - Public and Allied Health and Health Sciences' subcommunity
(before duplicates are removed):
  2 + 23 + 149 + 72 + 577 + 14 = 837 items as given by this query & by the
  DSpace GUI title-count for each collection. However, the DSpace GUI
  title-count for subcommunity '08 - Public and Allied Health and Health Sciences'
  is 832. Why?
"

##############################################################################
psql_opts="-U $user -d $db -A -c \"$query\""
cmd="psql $psql_opts"

cat <<-EOF

	DESCRIPTION: $descr

	COMMAND: $cmd
	---
EOF
eval $cmd

