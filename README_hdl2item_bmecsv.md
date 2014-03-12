hdl2item_bmecsv.rb
==================

Description
-----------

- hdl2item_bmecsv.rb: Convert handle to item_id for the DSpace 3.x
  Batch Metadata Editing Tool (BMET) CSV file.

- dspace_resource.rb: This file can be used as a library or a command
  line tool to look up a specified handle and returns the corresponding
  resource ID.  ie. item_id, collection_id or community_id.
  Typically, we like to reference DSpace items via their handle, but
  the BMET will only accept the item_id in the 'id' field. This script
  can be used with the following workflow.
  - create a BMET CSV file, but with the item-handle instead of the id
  - run this script to convert item-handle into the (item) id
  - import the CSV file into DSpace using the command:
```
      dspace metadata-import ...
```

Example usage
-------------

Example command line usage
```
bin/dspace_resource.rb  in_file.csv  >  out_file.csv
```

Example input CSV file (eg. in_file.csv)
```
item_handle,collection,dc.title
123456789/5235,123456789/5057,"My title"
```

Example CSV output (eg. out_file.csv) after processing with
hdl2item_bmecsv.rb. This assumes that the DSpace database lookup
of handle 123456789/5235 gives the item_id (ie. resource_id with
resource_type of :item) of 5177.
```
"id","collection","dc.title"
"5177","123456789/5057","My title"
```

Prerequisites
-------------
For the dspace_resource.rb library and hence hdl2item_bmecsv.rb
(and other apps in this repo) 
to connect to the DSpace database, you will need create a file
named dbc.rb and put it in your ruby library path (eg.
$HOME/my/db/connection/path/dbc.rb).  The parameters of the
Ruby hash can be a selection of those listed under
*PG::Connection.new(connection_hash)* at
http://deveiate.org/code/pg/PG/Connection.html#method-c-new

An example of dbc.rb:
```
module DbConnection

  # For the 'pg' library
  DB_CONNECT_INFO = {
    :dbname => "my_dspace_database_name",
    :user => "my_db_username",

    # If applicable, configure password, remote host, etc.
    #:password => "my_db_password",
    #:host => "db_remote_host",
  }

end
```

Make the file readable only by your user. Eg.
```
chmod 600 $HOME/my/db/connection/path/dbc.rb
```

