#!/bin/sh
##############################################################################
user=$USER	# Database user: Assume same name as the Unix user
db=dspace	# Database name

sql="
select
  'http://hdl.handle.net/' || h.handle handle,
  com2c.community_id comm_id,
  com2c.collection_id c_id,
  (select name from community where community_id=com2c.community_id) community_name,
  (select name from collection where collection_id=com2c.collection_id) collection_name
from
  community2collection com2c,
  handle h
where
  com2c.collection_id = h.resource_id
  and h.resource_type_id = 3
  and com2c.community_id in
    (select child_comm_id from community2community where parent_comm_id in
      (select community_id from community where name='ERA 2012')
    )
order by collection_name
"

query="copy (
$sql
)
to stdout
with
  delimiter ','
  csv
    header
    force quote handle, community_name, collection_name
"

descr="List Handle vs Collection Name after importing new ERA 2012 structure."

##############################################################################
psql_opts="-U $user -d $db -A -c \"$query\""
cmd="psql $psql_opts"

cat <<-EOF

	DESCRIPTION: $descr

	COMMAND: $cmd
	---
EOF
eval $cmd

