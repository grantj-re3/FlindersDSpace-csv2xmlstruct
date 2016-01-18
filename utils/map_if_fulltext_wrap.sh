#!/bin/sh
# map_if_fulltext_wrap.sh
#
# Copyright (c) 2015, Flinders University, South Australia. All rights reserved.
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

# 1=Dry run; 0=Real run.
# A dry run will run most features and generate most log files. If the BMET
# CSV file and fix_last_modified() SQL file would normally be generated, then
# they will be. A dry run will *bypass* execution of BMET import (ie. item
# mapping) and execution of SQL file to update the last_modified field.
IS_DRY_RUN=0							# Customise
DRY_RUN_PREFIX="DRY RUN: "
[ $IS_DRY_RUN = 0 ] && DRY_RUN_PREFIX=""

TIMESTAMP_PRETTY=`date "+%Y-%m-%d %H:%M:%S"`			# Timestamp for humans
TIMESTAMP=`echo "$TIMESTAMP_PRETTY" |tr -d ":-" |tr ' ' .`	# Timestamp for filenames
REF="Job reference: $DRY_RUN_PREFIX$TIMESTAMP"

IMPORT_CMD="$HOME/dspace/bin/dspace metadata-import -s -f"	# Customise

BASE_DIR=$HOME/opt/importERA					# Customise
MK_BMET_CSV_CMD=$BASE_DIR/utils/map_if_bitstream.rb

DEST_DIR=$BASE_DIR/map_if_fulltext
DEST_REPORT=$DEST_DIR/map_report.$TIMESTAMP.txt
DEST_REPORT_HEADER=$DEST_DIR/map_report_hdr.$TIMESTAMP.txt
DEST_REPORT_DRY_RUN=$DEST_DIR/map_report$TIMESTAMP.dryrun
DEST_CSV=$DEST_DIR/map_bmet.$TIMESTAMP.csv
ERROR_LOG=$DEST_DIR/map_bmet.$TIMESTAMP.err
IMPORT_LOG=$DEST_DIR/map_bmet.$TIMESTAMP.log
SQL_FNAME=$DEST_DIR/map_bmet.$TIMESTAMP.sql
SQL_LOG=$DEST_DIR/map_bmet.${TIMESTAMP}_sql.log

# mailx: Space separated list of destination email addresses
EMAIL_DEST_LIST="user@example.com"				# Customise
EMAIL_SUBJECT="${DRY_RUN_PREFIX}FAC full-text mapping report: $TIMESTAMP_PRETTY"
EMAIL_SUBJECT_ERROR="${DRY_RUN_PREFIX}FAC full-text mapping report ERROR: $TIMESTAMP_PRETTY"

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
    opts_attachments="-a $DEST_REPORT"
    [ -f $IMPORT_LOG ] && opts_attachments="$opts_attachments -a $IMPORT_LOG"
    [ -f $SQL_LOG ] && opts_attachments="$opts_attachments -a $SQL_LOG"
    (
      echo "$REF"
      echo
      echo "$error_type **ERROR** = '$error_code'" |tee $ERROR_LOG
      echo "The items might not be mapped to the destination collection"

      cat $DEST_REPORT_HEADER
    ) | mailx $opts_attachments -s "$EMAIL_SUBJECT_ERROR" $EMAIL_DEST_LIST
    exit $error_code
  fi
}

##############################################################################
# If we map the item into a new collection we should update the last_modified
# field (so that it appears in OAI-PMH for the newly mapped collection).
# This may not be necessary if the DSpace 3.1 embargo-lifter were to update
# the last_modified field (but it doesn't appear to).
##############################################################################
fix_last_modified() {
  awk -F, '
    NR>1 {
      printf("select h.handle, i.item_id, i.last_modified, now() from item i, handle h where h.resource_type_id=2 and i.item_id=h.resource_id and i.item_id='\''%s'\'';\n", $1)

      #printf("update item set last_modified=now() where item_id='\''%s'\'' and last_modified < (now() - interval '\''22 hours'\'');\n", $1)
      printf("update item set last_modified=now() where item_id='\''%s'\'';\n", $1)
    }
  ' $DEST_CSV > $SQL_FNAME

  cmd="echo \"${DRY_RUN_PREFIX}FixLastModified\" >> $SQL_LOG 2>&1"	# Dummy command
  [ $IS_DRY_RUN = 0 ] && cmd="psql -f $SQL_FNAME >> $SQL_LOG 2>&1"	# Update DB
  eval $cmd
  return $?
}

##############################################################################
# Main()
##############################################################################
[ ! -d $DEST_DIR ] && mkdir $DEST_DIR
[ $IS_DRY_RUN != 0 ] && touch $DEST_REPORT_DRY_RUN	# Show that logs are for a dry run

$MK_BMET_CSV_CMD > $DEST_CSV 2> $DEST_REPORT	# Create BMET CSV file
res=$?
awk '
  BEGIN {is_start=1}
  /^ITEMS BEING MAPPED/ {is_start=0}
  is_start==1 {print}
' $DEST_REPORT > $DEST_REPORT_HEADER

email_exit_on_error $res Ruby

if [ `wc -l < $DEST_CSV` -ge 2 ]; then		# At least 1 item to import
  cmd="echo \"${DRY_RUN_PREFIX}Import\" 2>&1 > $IMPORT_LOG"		# Dummy command
  [ $IS_DRY_RUN = 0 ] && cmd="$IMPORT_CMD $DEST_CSV 2>&1 > $IMPORT_LOG"	# Perform BMET import
  eval $cmd
  email_exit_on_error $? Import

  fix_last_modified
  email_exit_on_error $? FixLastModified
fi

opts_attachments="-a $DEST_REPORT"
[ -f $IMPORT_LOG ] && opts_attachments="$opts_attachments -a $IMPORT_LOG"
(
  echo "$REF"
  cat $DEST_REPORT_HEADER
) |mailx $opts_attachments -s "$EMAIL_SUBJECT" $EMAIL_DEST_LIST	# Email a report

