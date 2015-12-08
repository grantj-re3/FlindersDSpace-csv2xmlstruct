#!/bin/sh
#
# Copyright (c) 2015, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
user=$USER	# Database user: Assume same name as the Unix user
db=dspace	# Database name

[ "$1" = "" -o "$1" = -h -o "$1" = --help ] && {
  echo "Usage:  `basename $0`  HANDLE" >&2
  echo "where HANDLE format is '123456789/11'" >&2
  exit 1
}

hdl="$1"

sql="
select
  h.handle,
  i.*,
  p.email,
  col.name collection_name,
  (select text_value from metadatavalue where item_id=i.item_id and metadata_field_id=
    (select metadata_field_id from metadatafieldregistry where element='title' and qualifier is null)
  ) item_title
from 
  handle h, 
  item i, 
  eperson p, 
  collection col
where
  h.handle='$hdl' and 
  h.resource_type_id=2 and 
  h.resource_id=i.item_id and 
  i.submitter_id=p.eperson_id and 
  i.owning_collection=col.collection_id
"

query="copy (
$sql
)
to stdout
with
  delimiter ','
  csv
    header
    force quote col_name, title
"

descr="Get item info"

##############################################################################
psql_opts="-U $user -d $db -A -c \"$query\""
cmd="psql $psql_opts"

cat <<-EOF >&2

	DESCRIPTION: $descr

	COMMAND: $cmd
	---
EOF
eval $cmd


