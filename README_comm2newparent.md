comm2newparent.sh
=================
Description
-----------

- comm2newparent.sh: This script moves a batch of DSpace communities -
  each from one parent community to another.
  It is effectively a DSpace batch community-filiator application.
  It allows the user to know which child communities are being
  moved and where they are being moved from/to. Features are given below:
  * Child communities are moved from one parent to another (by using
    DSpace community-filiator --remove then --set).
  * Records (consisting of child, current parent and new parent community
    handles) are processed in an *interactive* batch.
  * The community *name* of each of the specified handles in the record
    is displayed to the user.
  * The program expects user confirmation before performing a batch move
    of communities.

- query.rb: Performs an SQL query or command.


Example configuration and usage
-------------------------------
Perform the steps below on a **test** server until you are familiar with
the operation.

Example configuration
- See Prerequisites section
- Confirm that bin/query.rb works with an example query. Eg.
```
# Generic PostgreSQL query
bin/query.rb "select name, abbrev from pg_timezone_names where name like 'Australia/%'"
# DSpace query
bin/query.rb "select distinct resource_type_id from handle"
```
- Edit the following within bin/comm2newparent.sh
  * DSPACE_CMD
  * move_config

Example command line usage
```
bin/comm2newparent.sh
# Then type 'p' to process the displayed records within DSpace or 'q' to quit without processing
```

Prerequisites
-------------

For query.rb and hence the comm2newparent.sh app (and other apps in this
repo) to connect to the DSpace database, you will need create a file named
dbc.rb as described [here](README70_hdl2item_bmecsv.md#prerequisites).

