#!/bin/sh
# Usage:  check_forgroup_field.sh > forgroup.log 2> forgroup.err
#
# Check that one of the dc.subject.forgroup fields agrees with the
# community dir
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
    echo "Checking dc.subject.forgroup at $path"

    forcodes=`egrep "element *= *\"subject\"" $path |
      egrep "qualifier *= *\"forgroup\"" |
      sed 's:</dcvalue>.$::; s:^.*>::; s: .*$::'`

    found=0
    for forcode in $forcodes; do
      field_regex="^$topdir/$forcode/"
      if echo "$path" |egrep -q "$field_regex"; then found=1; fi
    done

    if [ $found != 1 ]; then
      echo "WARNING: No dc.subject.forgroup (`echo $forcodes|tr ' ' ,`) matches SAF collection-dir $path" >&2
    fi
  done

