#!/bin/sh
# check_filename_matches_rmid.sh
#
# Copyright (c) 2018, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE:
# - Wrapper script for check_filename_matches_rmid.rb See the script for details.
# - Send STDERR as an email report & STDOUT as an email attachment.
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin ; export PATH

TIMESTAMP_PRETTY=`date "+%F %T"`	# Timestamp for humans
TIMESTAMP=`echo "$TIMESTAMP_PRETTY" |tr -d ":-" |tr ' ' _`	# Timestamp for filenames

APP_DIR_TMP=`dirname "$0"`	# Might be relative (eg "." or "..") or absolute
APP_DIR=`cd "$APP_DIR_TMP" ; pwd`	# Absolute path of app dir
APP_EXE="$APP_DIR/`basename $0 .sh`.rb"

TOP_DIR=`cd "$APP_DIR/.." ; pwd`	# Absolute path of parent of app dir
TMP_DIR="$TOP_DIR/tmp"
BAD_FILENAMES_CSV_FPATH="$TMP_DIR/bad_filenames_$TIMESTAMP.csv"

# mailx: Space separated list of destination email addresses
EMAIL_DEST_LIST="user@example.com"	# Customise
EMAIL_SUBJECT="Check filename matches RMID: $TIMESTAMP_PRETTY"

##############################################################################
[ ! -d "$TMP_DIR" ] && mkdir "$TMP_DIR"

# The sleep command is to avoid a race condition where the CSV file has not
# finished being written before the mailx command needs it.
$APP_EXE 2>&1  > "$BAD_FILENAMES_CSV_FPATH" |
  (sleep 4; cat) |
  mailx -a "$BAD_FILENAMES_CSV_FPATH" -s "$EMAIL_SUBJECT" $EMAIL_DEST_LIST

rm -f "$BAD_FILENAMES_CSV_FPATH"

