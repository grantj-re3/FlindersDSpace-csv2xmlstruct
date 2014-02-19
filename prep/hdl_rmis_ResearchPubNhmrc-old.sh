#!/bin/sh
##############################################################################
user=$USER	# Database user: Assume same name as the Unix user
db=dspace	# Database name

sql="
select
  c2i.item_id,
  mv.text_value rmid,
  mv2.text_value handle,
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
    LEFT OUTER JOIN metadatavalue mv2 on (c2i.item_id=mv2.item_id and mv2.metadata_field_id in
      (select metadata_field_id from metadatafieldregistry where element='identifier' and qualifier='uri')
      and mv2.text_value like 'http://hdl.handle.net/2328/%'
    )
where
  com2c.community_id in
    (select community_id from community where name='Research Publications')
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

descr="List all items within each collection directly under the
'Research Publications' community (ie. the NHMRC collection).

NOTES:

1) None of the items have an RMID.
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

