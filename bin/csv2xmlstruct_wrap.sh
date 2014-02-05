#!/bin/sh
# APPFILENAME_wrap.sh
# A generic wrapper script for a ruby script with filename APPFILENAME.rb
#
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
# The ruby application expects you to run it from the directory where
# it is located.  If you invoke the app via this wrapper script, then
# you can run it from anywhere.
#
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin;  export PATH

# This wrapper script & ruby app live in the same dir.
app_dir=`dirname "$0"`
filename_sh_app=`basename "$0"`

# This wrapper-script filename and ruby-app filename must be related as follows:
#   APPFILENAME.rb = APPFILENAME_wrap.sh
# where APPFILENAME is the basename of the ruby app (without the file extension).
filename_ruby_app=`echo "$filename_sh_app" |sed 's/_wrap.sh$/.rb/'`

# Run the ruby app
cd "$app_dir" && ruby "$filename_ruby_app" $@

