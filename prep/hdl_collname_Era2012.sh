#!/bin/sh
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
user=$USER	# Database user: Assume same name as the Unix user
db=dspace	# Database name

sql="
select
  com2c.collection_id,
  h.handle handle,
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
    force quote collection_id, handle, collection_name
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

