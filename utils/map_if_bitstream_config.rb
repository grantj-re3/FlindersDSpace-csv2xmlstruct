#
# Copyright (c) 2019, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Config vars for ruby

module Items4MappingConfig

  # true = source items from all collections (ie. ignore SOURCE_COLLECTION_HANDLE);
  # false = source items from the collection specified by SOURCE_COLLECTION_HANDLE
  IS_SOURCE_ALL_COLLECTIONS = false				# Customise
  SOURCE_COLLECTION_HANDLE = '123456789/6225'			# Customise - ARC collection contains items with bs, no bs, embargoed bs
  DEST_COLLECTION_HANDLE   = '123456789/6226'			# Customise - Flinders Open Access Research
  MORE_EXCLUDE_COLLECTION_HANDLES = []				# Customise - list of *extra* collection-handles to be excluded from mapping
  FULL_EXCLUDE_COLLECTION_HANDLES = [DEST_COLLECTION_HANDLE] + MORE_EXCLUDE_COLLECTION_HANDLES

  HANDLE_URL_LEFT_STRING = 'https://dspace.example.com/xmlui/handle/'	# Customise

  WILL_SHOW_RMID = true						# Customise

  MAX_ITEMS_TO_PROCESS = 100			# DSpace 3 manual recommends 1000 BMET records max
  MAX_ITEMS_WARN_MSG = <<-MSG_WARN1.gsub(/^\t*/, '')
	**WARNING**
	  The number of new full-text items has reached the mapping run-limit of #{MAX_ITEMS_TO_PROCESS}.
	  It is recommended that you check that this high-number of items is expected.
  MSG_WARN1

end

