#!/bin/sh
#
# WARNING: USE THIS SCRIPT WITH GREAT CAUTION... as per message below.
#
# Usage:  sh del_lang_field.sh [--force] > lang.log 2> lang.err
# Delete the dc.language[.*] field within all SAF-tree dublin_core.xml files.
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################

# Test paths against this regular expression (because we don't want the
# find command to cause processing of the wrong SAF file paths)
ok_regex="^FAC/[0-9]{4}/[0-9]{10}/dublin_core.xml$"


##############################################################################
if [ "$1" != --force ]; then
	cat <<-EOMSG >&2

		WARNING: USE THIS SCRIPT WITH GREAT CAUTION...

		because it irreversibly mangles DSpace Simple Archive Format (SAF)
		dublin_core.xml files. Hence:
		- Consider creating a backup and copying it off-host
		- Consider never giving this script execute Unix-permissions
		  ie. run using 'sh' on the command line
		- Ensure the find command is pointing to the correct SAF-tree
		- Ensure you have updated Regular Expression variable 'ok_regex'
		  to only process an SAF-tree of the correct format


		ok_regex is currently:  '$ok_regex'

	EOMSG
	exit 1
fi

##############################################################################
match_field_regex="<dcvalue .*element *= *\"language"

find FAC -name dublin_core.xml |
  sort |
  while read path; do
    echo "Removing dc.language[.*] fields from file $path"
    if echo "$path" |egrep -qv "$ok_regex"; then
      echo "ERROR: Path $path does not look like an RMIS SAF-tree as per RegEx '$ok_regex'"
      exit 1
    fi

    temp_path="$path.temp"
    egrep -v "$match_field_regex" $path > $temp_path	# Remove dc.language[.*]
    mv -f $temp_path $path				# Replace original file
  done

