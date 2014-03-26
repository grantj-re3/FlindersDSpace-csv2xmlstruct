erasaf_mkimport.rb
==================

Description
-----------
_erasaf_mkimport_: Makes a SAF import sh/bash script based on the the
contents of an ERA SAF tree and an existing ERA structure of communities
and collections within DSpace.


ERA SAF Tree Structure
----------------------

The Simple Archive Format (SAF) tree structure and DSpace ERA tree
structure are discussed [here](README_erasaf_pluckitem.md#era-saf-tree-structure).

Example configuration and usage
-------------------------------
Perform the steps below on a **test** server until you are familiar with
the operation.

Example configuration
- See Prerequisites section

- Modify the constants within bin/erasaf_mkimport.rb to suit your site.
  The ones most likely to require modification are:
  * IS_IMPORT_TEST
  * IS_EXPAND_SOURCE_PATH
  * IS_EXPAND_MAP_PATH
  * DSPACE_EXE_PATH
  * DSPACE_EPERSON_EMAIL

- Make an import sh/bash script (eg. from the supplied test data). This
  assumes you have a corresponding DSpace ERA-year tree structure with
  handle 123456789/5055.

```
cd test
tar zxvpf test_erasaf_mkimport.tar.gz
cd test_erasaf_mkimport
../../bin/erasaf_mkimport.rb mitest01 123456789/5055 > my_era_import.sh
```

- Review contents of my_era_import.sh

- Run the import

```
sh my_era_import.sh
```

- Verify the items defined with the ERA SAF tree now exist within
  DSpace.

Prerequisites
-------------
For erasaf_mkimport.rb (and other apps in this repo) to connect to the
DSpace database, you will need create a file named dbc.rb as described
[here](README_hdl2item_bmecsv.md#prerequisites).

