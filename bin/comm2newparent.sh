#!/bin/sh
# comm2newparent.sh
# Moves a batch of DSpace communities - each from one parent community to another.
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
# This script does not have a pretty output! It is just intended to
# provide confidence that we know which child communities are being
# moved and where they are being moved from/to.
#
# I've decoupled this script from the query-script so that we don't
# need to repeat database connection credentials here.
#
# Future:
# - Permit srcParentHdl to be "/" representing a top-level community.
#   Hence "$DSPACE_CMD community-filiator -r ..." would be unnecessary.
# - Consider putting the config in a CSV file so that non-technical
#   people can specify the community movements. Too risky?
#
##############################################################################
DSPACE_CMD=$HOME/dsbin/dspace		# Path to 'dspace' command line app
QUERY_CMD=`dirname "$0"`/query.rb	# query.rb is in same dir as this script

# Populate "move_config" variable below with:
# - childHdl:     handle of subcommunity to be moved
# - srcParentHdl: handle of current (source) parent community
# - dstParentHdl: handle of new (destination) parent community
# Rows shall consist of these 3 handles per line, space separated.
#
# Notes:
# - All handles are for communities (not collections or items).
# - Within "move_config", comment lines are permitted by adding "#"
#   as the first character on the line which is not a space or tab.
# - Within "move_config", blank lines are permitted.
#
# Field positions are:
#	childHdl	srcParentHdl	dstParentHdl
move_config="
	# 123456789/5121	123456789/5055	123456789/5236
	# 123456789/5138	123456789/5055	123456789/5236
"

##############################################################################
# do_command(cmd, is_show_cmd[, msg[, is_dry_run]]) -- Execute a shell command
##############################################################################
# - If msg is not empty, write it to stdout else do not.
# - If is_show_cmd==1, write command 'cmd' to stdout else do not.
# - If is_dry_run!=1, execute command 'cmd'
do_command() {
  cmd="$1"
  is_show_cmd=$2
  msg="$3"
  is_dry_run="$4"

  [ "$msg" != "" ] && echo "$msg"
  [ $is_show_cmd = 1 ] && echo "Command: $cmd"
  if [ "$is_dry_run" = 1 ]; then
    echo "DRY RUN: Not executing the above command."
  else
    eval $cmd
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "Error returned by command (ErrNo: $retval)" >&2
      exit $retval
    fi
  fi
}

##############################################################################
# get_community_name_by_handle(handle, sql_cmd)
##############################################################################
get_community_name_by_handle() {
  hdl="$1"
  sql="
    select c.name, h2.handle from
    community c,
    ( select resource_id,handle from handle
      where resource_type_id=4 and handle='$hdl' ) h2
    where c.community_id = h2.resource_id;
  "
  cmd="$QUERY_CMD \"$sql\""
  result=`eval $cmd`
}

##############################################################################
# show_community_name(handle, community_type)
##############################################################################
show_community_name() {
  hdl="$1"
  community_type="$2"
  get_community_name_by_handle "$hdl"
  echo "  $community_type -- $result"
}

##############################################################################
# Main()
##############################################################################
echo "Moving child community from one parent community to another"
echo "-----------------------------------------------------------"

# First time through is a dry-run. After user confirmation, second time
# through will process using the DSpace community-filiator commands.
for is_dry_run in 1 0; do

  line_num=0
  echo "$move_config" |
    while read child srcParent dstParent; do
      [ x$child = x ] && continue				# Skip blank lines
      if echo "$child" |egrep -q "^[ 	]*#"; then continue; fi	# Skip comment lines
      line_num=`expr $line_num + 1`
      echo
      echo "[$line_num] Move child $child from parent $srcParent to parent $dstParent"

      show_community_name "$child"     "Child         "
      show_community_name "$srcParent" "Current parent"
      show_community_name "$dstParent" "New parent    "

      cmd="$DSPACE_CMD community-filiator -r -c $child -p $srcParent"
      do_command "$cmd" 1 '' $is_dry_run
      cmd="$DSPACE_CMD community-filiator -s -c $child -p $dstParent"
      do_command "$cmd" 1 '' $is_dry_run
    done					# while read

  if [ $is_dry_run = 1 ]; then
    echo
    echo "Please review the above actions."
    echo "Would you like to [p]rocess the above actions or [q]uit? Enter p or q "
    read ans
    [ "$ans" != p ] && exit 0
  fi

done						# for is_dry_run

