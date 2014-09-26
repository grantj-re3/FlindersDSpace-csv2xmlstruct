#!/bin/sh
# Usage:  check_rmid_field.sh > rmid.log 2> rmid.err
#
# Check the dc.identifier.rmid agrees with item dir
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################

# All SAF-tree paths should be:
#   $topdir/FORCODE/RMID/$fname
#
# where
# - FORCODE is the first 4-digits of one of the multi-valued
#   dc.subject.forgroup fields (and represents an SAF-tree collection-dir)
# - RMID is the value of the dc.identifier.rmid field (and
#   represents an SAF-tree item-dir)
topdir=FAC
fname=dublin_core.xml

##############################################################################
find $topdir -name $fname |
  sort |
  while read path; do
    echo "Checking dc.identifier.rmid at $path"

    rmid=`egrep "qualifier *= *\"rmid\"" $path |
      egrep "element *= *\"identifier\"" |
      sed 's:</dcvalue>.$::; s:^.*>::'`

    field_regex="/$rmid/$fname$"
    if echo "$path" |egrep -qv "/$rmid/$fname$"; then
      echo "WARNING: dc.identifier.rmid '$rmid' does not match SAF item-dir $path" >&2
    fi

  done

