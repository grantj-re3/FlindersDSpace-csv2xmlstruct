Batch Metadata Editing Tool (BMET)
==================================

## Metadata fields have a given language

Metadata fields have an associated language eg. en_US.
For DSpace 3.x, the default.language value specified in dspace.cfg
appears to apply to web submission forms and Simple Archive Format
import records but not to the BMET.

However when you edit fields using the BMET, you have the option to specify
the language with a CSV file like so:
```
id,collection,dc.type[en_US]
11,123456789/1,Article
22,123456789/1,Book
```

rather than:
```
id,collection,dc.type
11,123456789/1,Article
22,123456789/1,Book
```

In the first example above, dc.type will be assigned a language of 'en_US'
whereas in the second example the dc.type will not be assigned a language.

Another interesting (and perhaps undesirable) consequence is that if you
were to use the BMET import function with the first CSV file then repeat
the process with the second CSV file those items would have __two__ dc.type
fields - (one with a language of 'en_US' and one without a language).

So when using the BMET to update a particular metadata field you may need to
be very careful in order to replace the intended field+language combo rather
than create a second field. This might not be a problem if:
- the given metadata field has all instances assigned to the same language, or
- you follow the BMET-export, edit-CSV, BMET-import workflow implied in the
  manual

I am assuming that having multiple metadata fields (eg. dc.type) with
different language qualifiers is not intentional. If it is in your case
then the solution below may not be useful to you.

__Potential solution__: You may wish to overcome this problem like this:
- determine which languages are used for the given metadata field (see below)
- in the CSV file to be imported, blank out (ie. delete) all but one of
  the columns (which I'll call the target column)
- put the desired metadata in the target column
- perform the BMET import function

Below is a CSV example where the third column (dc.type[en_US]) is populated
but the last 2 columns are empty (resulting in those fields being deleted).
```
id,collection,dc.type[en_US],dc.type,dc.type[en]
11,123456789/1,Article,,
22,123456789/1,Book,,
```

### How to determine which languages are used for a given metadata field

Below are some examples.

#### dc.type
Count each:
```
select
  'dc.type'||(case when text_lang is null then '' else '['||text_lang||']' end) dc,
  count(*)
from metadatavalue
where metadata_field_id=
  (select metadata_field_id from metadatafieldregistry where element='type' and qualifier is null)
group by 1
order by 1;
```

Output:
```
       dc       | count
----------------+-------
 dc.type        |     9
 dc.type[]      |     2
 dc.type[en]    |  1364
 dc.type[en_au] |     4
 dc.type[en_US] |  9757
(5 rows)
```

Produce a CSV list:
```
select array_to_string(array(
  select distinct 'dc.type'||(case when text_lang is null then '' else '['||text_lang||']' end) dc
  from metadatavalue
  where metadata_field_id=
    (select metadata_field_id from metadatafieldregistry where element='type' and qualifier is null)
  order by 1
), ',') dc_type_csv;
```

Output:
```
                         dc_type_csv
-------------------------------------------------------------
 dc.type,dc.type[],dc.type[en],dc.type[en_au],dc.type[en_US]
```

#### dc.subject.forgroup
Count each:
```
select
  'dc.subject.forgroup'||(case when text_lang is null then '' else '['||text_lang||']' end) dc,
  count(*)
from metadatavalue
where metadata_field_id=
  (select metadata_field_id from metadatafieldregistry where element='subject' and qualifier='forgroup')
group by 1
order by 1;
```

Produce a CSV list:
```
select array_to_string(array(
  select distinct 'dc.subject.forgroup'||(case when text_lang is null then '' else '['||text_lang||']' end) dc
  from metadatavalue
  where metadata_field_id=
    (select metadata_field_id from metadatafieldregistry where element='subject' and qualifier='forgroup')
  order by 1
), ',') dc_subject_forgroup_csv;
```

