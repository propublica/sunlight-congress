# Bills

Data on bills in Congress goes back to 2009, and comes from a mix of sources:

* Scrapers at [github.com/unitedstates](https://github.com/unitedstates/congress) for core status and history information.
* Bulk data at [GPO's FDSys](http://www.gpo.gov/fdsys/) for the full text.
* The House' [MajorityLeader.gov](http://majorityleader.gov/) and Senate Democrat's [official site](http://democrats.senate.gov/) for notices of upcoming debate.

## Methods

All requests require a valid [API key](index.html#apikey).

### /bills

### /bills/search

## Fields

All examples below are from H.R. 3590 of the 111th Congress, the Patient Protection and Affordable Care Act (Obamacare).

* = can be used as a filter

```json
{
  "bill_id": "hr3590-111", 
  "bill_type": "hr", 
  "number": 3590, 
  "congress": 111, 
  "introduced_on": "2009-09-17"
}
```

**bill_id** (string) *
<br/>The unique ID for this bill. Formed from the `bill_type`, `number`, and `congress`.

**bill_type** (string) *
<br/>The type for this bill. For the bill "H.R. 4921", the `bill_type` represents the "H.R." part. Bill types can be: **hr**, **hres**, **hjres**, **hconres**, **s**, **sres**, **sjres**, **sconres**.

**number** (number) *
<br/>The number for this bill. For the bill "H.R. 4921", the `number` is 4921.

**congress** (number) *
<br/>The Congress in which this bill was introduced. For example, bills introduced in the "111th Congress" have a `congress` of 111.

**introduced_on** (date) *
<br/>The date this bill was introduced.


### Titles

```json
{
  "official_title": "An act entitled The Patient Protection and Affordable Care Act.", 
  "popular_title": "Health care reform bill", 
  "short_title": "Patient Protection and Affordable Care Act",

  "titles": [
    {
      "as": null, 
      "title": "Health care reform bill", 
      "type": "popular"
    }, 
    {
      "as": "enacted", 
      "title": "Patient Protection and Affordable Care Act", 
      "type": "short"
    }, 
    {
      "as": "amended by senate", 
      "title": "An act entitled The Patient Protection and Affordable Care Act.", 
      "type": "official"
    }
  ]
}
```

**official_title** (string)<br/>
The current official title of a bill. Official titles are sentences. Always present. Assigned at introduction, and can be revised any time.

**short_title** (string)<br/>
The current shorter, catchier title of a bill. About half of bills get these, and they can be assigned any time.

**popular_title** (string)<br/>
The current popular handle of a bill, as denoted by the Library of Congress. They are rare, and are assigned by the LOC for particularly ubiquitous bills. They are non-capitalized descriptive phrases. They can be assigned any time.

**titles** (array)<br/>
A list of all titles ever assigned to this bill, with accompanying data.

**titles.as** (string)<br/>
The state the bill was in when assigned this title.

**titles.title** (string)<br/>
The title given to the bill.

**titles.type** (string)<br/>
The type of title this is. "official", "short", or "popular".

### Summary and keywords

```json
{
  "subjects": [
    "Abortion", 
    "Administrative law and regulatory procedures", 
    "Adoption and foster care",
    ...
  ], 

  "summary": "Patient Protection and Affordable Care Act - Title I: Quality, Affordable Health Care for All Americans..."
}
```

**summary** (string)<br/>
An official summary written and assigned at some point after introduction by the Library of Congress. These summaries are generally more accessible than the text of the bill, but can still be technical. The LOC does not write summaries for all bills, and when they do can assign and revise them at any time.

**keywords** (array of strings)<br/>
A list of official keywords and phrases assigned by the Library of Congress. These keywords can be used to group bills into tags or topics, but there are many of them (1,023 unique keywords since 2009, as of late 2012), and they are not grouped into a hierarchy. They can be assigned or revised at any time after introduction.

### History

```json
{
  "history": {
    "house_passage_result": "pass", 
    "house_passage_result_at": "2010-03-21T22:48:00-05:00", 
    "senate_cloture_result": "pass",
    "senate_cloture_result_at": "2009-12-23",
    "senate_passage_result": "pass", 
    "senate_passage_result_at": "2009-12-24", 
    "vetoed": false,
    "awaiting_signature": false, 
    "enacted": true, 
    "enacted_at": "2010-03-23"
  }
}
```

The **history** field includes useful flags and dates/times in a bill's life. The above is a real-life example of H.R. 3590 - not all fields will be present for every bill.

Time fields can hold either dates or times - Congress is inconsistent about providing specific timestamps.

**history.house_passage_result** (string)<br/>
The result of the last time the House voted on passage. Only present if this vote occurred. "pass" or "fail".

**history.house_passage_result_at** (date or time)<br/>
The date or time the House last voted on passage. Only present if this vote occurred.

**history.senate_cloture_result** (string)<br/>
The result of the last time the Senate voted on cloture. Only present if this vote occurred. "pass" or "fail".

**history.senate_cloture_result_at** (date or time)<br/>
The date or time the Senate last voted on cloture. Only present if this vote occurred.

**history.senate_passage_result** (string)<br/>
The result of the last time the Senate voted on passage. Only present if this vote occurred. "pass" or "fail".

**history.senate_passage_result_at** (date or time)<br/>
The date or time the Senate last voted on passage. Only present if this vote occurred.

**history.vetoed** (boolean)<br/>
Whether the bill has been vetoed by the President. Always present.

**history.vetoed_at** (date or time)<br/>
The date or time the bill was vetoed by the President. Only present if this happened.

**history.house_override_result** (string)<br/>
The result of the last time the House voted to override a veto. Only present if this vote occurred. "pass" or "fail".

**history.house_override_result_at** (date or time)<br/>
The date or time the House last voted to override a veto. Only present if this vote occurred.

**history.senate_override_result** (string)<br/>
The result of the last time the Senate voted to override a veto. Only present if this vote occurred. "pass" or "fail".

**history.senate_override_result_at** (date or time)<br/>
The date or time the Senate last voted to override a veto. Only present if this vote occurred.

**history.awaiting_signature** (boolean)<br/>
Whether the bill is currently awaiting the President's signature. Always present.

**history.awaiting_signature_since** (date or time)<br/>
The date or time the bill began awaiting the President's signature. Only present if this happened.

**history.enacted** (boolean)<br/>
Whether the bill has been enacted into law. Always present.

**history.enacted_at** (date or time)<br/>
The date or time the bill was enacted into law. Only present if this happened.


### Actions

### Sponsorships

### Committees

### Amendments

### Related Bills

### Becoming Law


### Example bill

This is the Patient Protection and Affordable Care Act (Obamacare).