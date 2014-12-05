#!/bin/sh
# map_if_bitstream_wrap.sh
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE:
# - Wrapper script for map_if_bitstream.rb. See the script for details.
# - Generate a DSpace Batch Metadata Editing Tool (BMET) CSV file.
# - Import into DSpace using the BMET.
# - Send an email report.
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin ; export PATH
TIMESTAMP_PRETTY=`date "+%Y-%m-%d %H:%M:%S"`			# Timestamp for humans
TIMESTAMP=`echo "$TIMESTAMP_PRETTY" |tr -d ":-" |tr ' ' .`	# Timestamp for filenames
REF="Job reference: $TIMESTAMP"

IMPORT_CMD="$HOME/dspace/bin/dspace metadata-import -s -f"	# Customise

BASE_DIR=$HOME/opt/importERA					# Customise
MK_BMET_CSV_CMD=$BASE_DIR/utils/map_if_bitstream.rb

DEST_DIR=$BASE_DIR/map_if_bitstream
DEST_REPORT=$DEST_DIR/map_report.$TIMESTAMP.txt
DEST_CSV=$DEST_DIR/map_bmet.$TIMESTAMP.csv
ERROR_LOG=$DEST_DIR/map_bmet.$TIMESTAMP.err
IMPORT_LOG=$DEST_DIR/map_bmet.$TIMESTAMP.log

# mailx: Space separated list of destination email addresses
EMAIL_DEST_LIST="user@example.com"				# Customise
EMAIL_SUBJECT="ERA item mapping report: $TIMESTAMP_PRETTY"
EMAIL_SUBJECT_ERROR="ERA item mapping report ERROR: $TIMESTAMP_PRETTY"

##############################################################################
# email_exit_on_error(error_code, error_type)
# On error:
# - Write the error to a log file
# - Send the error via email
# - Exit script
##############################################################################
email_exit_on_error() {
  error_code="$1"
  error_type="$2"

  if [ $error_code != 0 ]; then
    (
      echo "$REF"
      echo "$error_type ERROR = $error_code" |tee $ERROR_LOG
      cat $DEST_REPORT
      [ -f $IMPORT_LOG ] && (echo; cat $IMPORT_LOG)
    ) | mailx -s "$EMAIL_SUBJECT_ERROR" $EMAIL_DEST_LIST
    exit $error_code
  fi
}

##############################################################################
# Main()
##############################################################################
[ ! -d $DEST_DIR ] && mkdir $DEST_DIR
$MK_BMET_CSV_CMD > $DEST_CSV 2> $DEST_REPORT	# Create BMET CSV file
email_exit_on_error $? Ruby

if [ `wc -l < $DEST_CSV` -ge 2 ]; then		# At least 1 item to import
  $IMPORT_CMD $DEST_CSV 2>&1 > $IMPORT_LOG	# Perform BMET import
  email_exit_on_error $? Import
fi

(
  echo "$REF"
  cat $DEST_REPORT
  [ -f $IMPORT_LOG ] && (echo; cat $IMPORT_LOG)
) |mailx -s "$EMAIL_SUBJECT" $EMAIL_DEST_LIST	# Email a report

