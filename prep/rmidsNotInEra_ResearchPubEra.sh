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
  item_id,
  (select text_value rmid from metadatavalue where item_id=item_rmid.item_id and metadata_field_id = 
    (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid')
  ) rmid,
  (select handle from handle where resource_id=item_rmid.item_id and resource_type_id=2) handle,
  (select name from collection where collection_id=
    (select owning_collection from item where item_id=item_rmid.item_id)
  ) owning_collection_name

from
  (select distinct item_id from metadatavalue where metadata_field_id = 
    (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='rmid')
  ) item_rmid

where item_id not in
  (select distinct c2i.item_id
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
)
order by owning_collection_name,item_id
"

query="copy (
$sql
)
to stdout
with
  delimiter ','
  csv
    header
    force quote owning_collection_name
"

descr="Show the RMID, handle and miscellaneous information regarding all
items which have an RMID but which are NOT owned by (or mapped to)
any collection under an ERA year.
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

