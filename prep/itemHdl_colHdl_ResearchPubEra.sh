#!/bin/sh
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
user=$USER	# Database user: Assume same name as the Unix user
db=dspace	# Database name

# The parent community of all of the ERA reporting-year communities.
parent_era_year_comm_name="Research Publications"

# A regex which matches all ERA reporting-year community names. These must
# be children of the above community.
era_year_comm_name_regex='^ERA 2010$'

sql="
select
  i.item_id,
  i.owning_collection col_owner,
  (select substring(name,1,10) from collection where collection_id=i.owning_collection) col_owner_name,
  array_to_string(array(
      select substring(name,1,10) from collection2item c2i2, collection c2 where c2i2.item_id=i.item_id and
      c2i2.collection_id <> i.owning_collection and c2i2.collection_id=c2.collection_id order by name
  ), '||') col_others_name,

  (select text_value from metadatavalue where item_id=i.item_id and metadata_field_id=
    (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid')
  ) rmid,
  (select handle from handle where resource_id=i.item_id and resource_type_id=2) item_hdl,
  (select handle from handle where resource_id=i.owning_collection and resource_type_id=3) col_owner_hdl,
  array_to_string(array(
      select handle from collection2item c2i2, handle where c2i2.item_id=i.item_id and
      c2i2.collection_id <> i.owning_collection and c2i2.collection_id=resource_id and
      resource_type_id=3 order by handle_id
  ), '||') col_others_hdl
from
(
  select
    distinct c2i.item_id, owning_collection
  from
    item,
    community2collection com2c,
    collection2item c2i
  where
    com2c.community_id in
      (select child_comm_id from community2community where parent_comm_id in
        (select community_id from community where name~'$era_year_comm_name_regex' and community_id in
          (select child_comm_id from community2community where parent_comm_id =
            (select community_id from community where name='$parent_era_year_comm_name')
          )
        )
      )
    and c2i.collection_id=com2c.collection_id
    and c2i.item_id not in (select item_id from item where withdrawn=true)
    and item.item_id = c2i.item_id
) i
order by rmid,item_id
"

query="copy (
$sql
)
to stdout
with
  delimiter ','
  csv
    header
    force quote col_owner_name, col_others_name
"

descr="Show the RMID, item-handle, owner-handle, list of
collection-handles and miscellaneous information for each item:
- within each collection
- under each sub-community
- under the communities which match the regex /$era_year_comm_name_regex/
- under the '$parent_era_year_comm_name' community.
(This deliberately excludes any collections directly beneath the
'$parent_era_year_comm_name' community).

NOTES:

1) Items which appear in more than one collection are only counted once.

2) Items may be owned by a collection within or outside an ERA
  reporting-year.

3) Items 8202,8206 have no RMID (so I presume they did not originate from RM).
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

