# Bills

Data on bills in Congress goes back to 2009, and comes from a mix of sources:

* Scrapers at [github.com/unitedstates](https://github.com/unitedstates/congress) for core status and history information.
* Bulk data at [GPO's FDSys](http://www.gpo.gov/fdsys/) for version information, and full text.
* The House' [MajorityLeader.gov](http://majorityleader.gov/) and Senate Democrat's [official site](http://democrats.senate.gov/) for notices of upcoming debate.

## Methods

All requests require a valid [API key](index.html#apikey), and use the domain:

```text
http://congress.api.sunlightfoundation.com
```

### /bills

Filter through bills in Congress. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#operators) apply.

**Bills enacted into law in the 112th Congress**

```text
/bills?congress=112&history.enacted=true
```

**Bills sponsored by Republicans that have been vetoed**

```text
/bills?sponsor.party=R&history.vetoed=true
```

**Most recent private laws**

```text
/bills?enacted.law_type=private&order=history.enacted_at
```

**Joint resolutions that received a vote in the House and Senate**

```text
/bills?bill_type__in=hjres|sjres&history.house_passage_result__exists=true&history.senate_passage_result__exists=true
```

### /bills/search

Search the full text of legislation, and other fields.

The `query` parameter allows wildcards, quoting for phrases, and nearby word operators ([full reference](index.html#search)) You can also retrieve [highlighted excerpts](index.html#highlighting), and all [normal operators](index.html#operators) and filters.

This searches the bill's full text, `short_title`, `official_title`, `popular_title`, `nicknames`, `summary`, and `keywords` fields.

**Bills matching "health care" that became law**

```text
/bills/search?query="health care"&history.enacted=true
```

**Recent bills matching "freedom of information" and words starting with "accountab"**

```text
/bills/search?query="freedom of information" accountab*&order=introduced_on
```

**Bills with "transparency" and "accountability" within 5 words of each other, with excerpts**

```text
/bills/search?query="transparency accountability"~5&highlight=true
```


## Fields

All examples below are from H.R. 3590 of the 111th Congress, the [Patient Protection and Affordable Care Act](http://www.govtrack.us/congress/bills/111/hr3590) (Obamacare).

\* = can be used as a filter

```json
{
  "bill_id": "hr3590-111", 
  "bill_type": "hr", 
  "number": 3590, 
  "congress": 111, 
  "chamber": "house",
  "introduced_on": "2009-09-17",
  "last_action_at": "2010-03-23",
  "last_vote_at": "2010-03-22T03:48:00Z",
  "last_version_on": "2012-08-25"
}
```

\* **bill_id**<br/>
The unique ID for this bill. Formed from the `bill_type`, `number`, and `congress`.

\* **bill_type**<br/>
The type for this bill. For the bill "H.R. 4921", the `bill_type` represents the "H.R." part. Bill types can be: **hr**, **hres**, **hjres**, **hconres**, **s**, **sres**, **sjres**, **sconres**.

\* **number**<br/>
The number for this bill. For the bill "H.R. 4921", the `number` is 4921.

\* **congress**<br/>
The Congress in which this bill was introduced. For example, bills introduced in the "111th Congress" have a `congress` of 111.

\* **chamber**<br/>
The chamber in which the bill originated.

\* **introduced_on**<br/>
The date this bill was introduced.

\* **last_action_at**<br/>
The date or time of the most recent official action.

\* **last_vote_at**<br/>
The date or time of the most recent vote on this bill.

\* **last_version_on**<br/>
The date the last version of this bill was published.

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

**official_title**<br/>
The current official title of a bill. Official titles are sentences. Always present. Assigned at introduction, and can be revised any time.

**short_title**<br/>
The current shorter, catchier title of a bill. About half of bills get these, and they can be assigned any time.

**popular_title**<br/>
The current popular handle of a bill, as denoted by the Library of Congress. They are rare, and are assigned by the LOC for particularly ubiquitous bills. They are non-capitalized descriptive phrases. They can be assigned any time.

**titles**<br/>
A list of all titles ever assigned to this bill, with accompanying data.

**titles.as**<br/>
The state the bill was in when assigned this title.

**titles.title**<br/>
The title given to the bill.

**titles.type**<br/>
The type of title this is. "official", "short", or "popular".

### Nicknames

```json
{
  "nicknames": [
    "obamacare",
    "ppaca"
  ]
}
```

\* **nicknames**<br/>
An array of common nicknames for a bill that don't appear in official data. These nicknames are sourced from a public dataset at [unitedstates/bill-nicknames](https://github.com/unitedstates/bill-nicknames), and will only appear for a tiny fraction of bills. In the future, we plan to auto-generate acronyms from bill titles and add them to this array.

### Summary and keywords

```json
{
  "subjects": [
    "Abortion", 
    "Administrative law and regulatory procedures", 
    "Adoption and foster care",
    ...
  ], 

  "summary": "Patient Protection and Affordable Care Act - Title I: Quality, Affordable Health Care for All Americans...",

  "summary_short": "Patient Protection and Affordable Care Act - Title I: Quality, Affordable Health Care for All Americans..."
}
```

\* **keywords**<br/>
A list of official keywords and phrases assigned by the Library of Congress. These keywords can be used to group bills into tags or topics, but there are many of them (1,023 unique keywords since 2009, as of late 2012), and they are not grouped into a hierarchy. They can be assigned or revised at any time after introduction.

**summary**<br/>
An official summary written and assigned at some point after introduction by the Library of Congress. These summaries are generally more accessible than the text of the bill, but can still be technical. The LOC does not write summaries for all bills, and when they do can assign and revise them at any time.

**summary_short**<br/>
The official summary, but capped to 1,000 characters (and an ellipse). Useful when you want to show only the first part of a bill's summary, but don't want to download a potentially large amount of text.

### URLs

```json
{
  "urls": {
    "congress" :"http://beta.congress.gov/bill/111th/house-bill/3590",
    "govtrack" :"http://www.govtrack.us/congress/bills/111/hr3590",
    "opencongress" :"http://www.opencongress.org/bill/111-h3590/show"
  }
}
```

**urls**
An object with URLs for this bill's landing page on Congress.gov, GovTrack.us, and OpenCongress.org.

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

\* **history.house_passage_result**<br/>
The result of the last time the House voted on passage. Only present if this vote occurred. "pass" or "fail".

\* **history.house_passage_result_at**<br/>
The date or time the House last voted on passage. Only present if this vote occurred.

\* **history.senate_cloture_result**<br/>
The result of the last time the Senate voted on cloture. Only present if this vote occurred. "pass" or "fail".

\* **history.senate_cloture_result_at**<br/>
The date or time the Senate last voted on cloture. Only present if this vote occurred.

\* **history.senate_passage_result**<br/>
The result of the last time the Senate voted on passage. Only present if this vote occurred. "pass" or "fail".

\* **history.senate_passage_result_at**<br/>
The date or time the Senate last voted on passage. Only present if this vote occurred.

\* **history.vetoed**<br/>
Whether the bill has been vetoed by the President. Always present.

\* **history.vetoed_at**<br/>
The date or time the bill was vetoed by the President. Only present if this happened.

\* **history.house_override_result**<br/>
The result of the last time the House voted to override a veto. Only present if this vote occurred. "pass" or "fail".

\* **history.house_override_result_at**<br/>
The date or time the House last voted to override a veto. Only present if this vote occurred.

\* **history.senate_override_result**<br/>
The result of the last time the Senate voted to override a veto. Only present if this vote occurred. "pass" or "fail".

\* **history.senate_override_result_at**<br/>
The date or time the Senate last voted to override a veto. Only present if this vote occurred.

\* **history.awaiting_signature**<br/>
Whether the bill is currently awaiting the President's signature. Always present.

\* **history.awaiting_signature_since**<br/>
The date or time the bill began awaiting the President's signature. Only present if this happened.

\* **history.enacted**<br/>
Whether the bill has been enacted into law. Always present.

\* **history.enacted_at**<br/>
The date or time the bill was enacted into law. Only present if this happened.


### Actions

```json
{
  "actions": [
    {
      "type": "vote", 
      "acted_at": "2010-03-21T22:48:00-05:00", 
      "chamber": "house",
      "how": "roll", 
      "vote_type": "pingpong", 
      "result": "pass", 
      "roll_id": "165", 
      "text": "On motion that the House agree to the Senate amendments Agreed to by recorded vote: 219 - 212 (Roll no. 165).", 
      "references": [
        {
          "reference": "CR H1920-2152", 
          "type": "text as House agreed to Senate amendments"
        }
      ]
    }, 
    {
      "type": "signed",
      "acted_at": "2010-03-23", 
      "text": "Signed by President.",
      "references": []
    }, 
    {
      "type": "enacted",
      "acted_at": "2010-03-23", 
      "text": "Became Public Law No: 111-148."
      "references": []
    }
  ]
}
```

The **actions** field has a list of all official activity that has occurred to a bill. All fields are parsed out of non-standardized sentence text, so mistakes and omissions are possible.

**actions.type**<br/>
The type of action. The default is "action", but there can be many others. Always present.

**actions.acted_at**<br/>
The date or time the action occurred. Always present.

**actions.text**<br/>
The official text that describes this action. Always present.

**actions.references**<br/>
A list of references to the Congressional Record that this action links to.

**actions.chamber**<br/>
Which chamber this action occured in. "house" or "senate".

**actions.vote_type**<br/>
If the action is a vote, this is the type of vote. "vote", "vote2", "cloture", or "pingpong".

**actions.how**<br/>
If the action is a vote, how the vote was taken. Can be "roll", "voice", or "Unanimous Consent".

**actions.result**<br/>
If the action is a vote, the result. "pass" or "fail".

**actions.roll_id**<br/>
If the action is a roll call vote, the ID of the roll call.

### Votes

```json
{
  "votes": [
    {
      "type": "vote", 
      "acted_at": "2010-03-21T22:48:00-05:00", 
      "chamber": "house",
      "how": "roll", 
      "vote_type": "pingpong", 
      "result": "pass", 
      "roll_id": "165", 
      "text": "On motion that the House agree to the Senate amendments Agreed to by recorded vote: 219 - 212 (Roll no. 165).", 
      "references": [
        {
          "reference": "CR H1920-2152", 
          "type": "text as House agreed to Senate amendments"
        }
      ]
    }
  ]
}
```

The **votes** array is identical to the `actions` array, but limited to actions that are votes.


### Sponsorships

```json
{
  "sponsor_id": "R000053",
  "sponsor": {
    "bioguide_id": "R000053",
    "in_office": true,
    "last_name": "Rangel"
    ...
  },

  "cosponsor_ids": [
    "B000287",
    "B001231"
    ...
  ],
  "cosponsors": [
    {
      "sponsored_at": "2009-09-17",
      "legislator": {
        "bioguide_id": "B000287",
        "in_office": true,
        "last_name": "Becerra"
        ...
      }
    }, 
    {
      "sponsored_at": "2009-09-17",
      "legislator": {
        "bioguide_id":"B001231",
        "in_office":true,
        "last_name":"Berkley"
        ...
      }
    },
    ...
  ],

  "withdrawn_cosponsor_ids": [],
  "withdrawn_cosponsors": []
}
```

\* **sponsor_id**<br/>
The bioguide ID of the bill's sponsor, if there is one. It is possible, but rare, to have bills with no sponsor.

**sponsor**<br/>
An object with most simple [legislator fields](legislators.html#fields) for the bill's sponsor, if there is one. 

\* **cosponsor_ids**<br/>
An array of bioguide IDs for each cosponsor of the bill. Bills do not always have cosponsors.

**cosponsors.sponsored_on**<br/>
When a legislator signed on as a cosponsor of the legislation.

**cosponsors.legislator**<br/>
An object with most simple [legislator fields](legislators.html#fields) for that cosponsor.

\* **withdrawn_cosponsor_ids**<br/>
An array of bioguide IDs for each legislator who has withdrawn their cosponsorship of the bill.

**withdrawn_cosponsors.withdrawn_on**<br/>
The date the legislator withdrew their cosponsorship of the bill.

**withdrawn_cosponsors.sponsored_on**<br/>
The date the legislator originally cosponsored the bill.

**withdrawn_cosponsors.legislator**<br/>
An object with most simple [legislator fields](legislators.html#fields) for that withdrawn cosponsor.

### Committees

```json
{
  "committee_ids": [
    "HSWM"
  ],
  "committees": [
    {
      "activity": [
        "referral"
      ],
      "committee": {
        "address": "1102 LHOB; Washington, DC 20515-6348",
        "chamber": "house",
        "committee_id": "HSWM",
        "house_committee_id": "WM",
        "name": "House Committee on Ways and Means",
        "office": "1102 LHOB",
        "phone": "(202) 225-3625",
        "subcommittee": false
      }
    }
  ]
}
```

\* **committee_ids**<br/>
A list of IDs of committees related to this bill.

**committees.activity**<br/>
A list of relationships that the committee has to the bill, as they appear on [THOMAS.gov](http://thomas.loc.gov). The most common is "referral", which means a committee has jurisdiction over this bill.

### Related Bills

```json
{
  "related_bill_ids": [
    "hconres254-111",
    "hres1203-111",
    "hr3780-111",
    "hr4872-111",
    "s1728-111",
    "s1790-111"
  ]
}
```

\* **related_bill_ids**<br/>
A list of IDs of bills that the Library of Congress has declared "related". Relations can be pretty loose, use this field with caution.

### Bill Versions

```json
{
  "versions": [
    {
      "version_code": "eas",
      "issued_on": "2009-12-24",
      "version_name": "Engrossed Amendment Senate",
      "bill_version_id": "hr3590-111-eas",
      "urls": {
        "html": "http://www.gpo.gov/fdsys/pkg/BILLS-111hr3590eas/html/BILLS-111hr3590eas.htm",
        "pdf": "http://www.gpo.gov/fdsys/pkg/BILLS-111hr3590eas/pdf/BILLS-111hr3590eas.pdf"
      }
    },
    {
      "version_code": "enr",
      "issued_on": "2010-08-25",
      "version_name": "Enrolled Bill",
      "bill_version_id": "hr3590-111-enr",
      "urls": {
        "html": "http://www.gpo.gov/fdsys/pkg/BILLS-111hr3590enr/html/BILLS-111hr3590enr.htm",
        "pdf": "http://www.gpo.gov/fdsys/pkg/BILLS-111hr3590enr/pdf/BILLS-111hr3590enr.pdf"
      }
    }
  ],
  "last_version": {
    "version_code": "enr",
    "issued_on": "2010-08-25",
    "version_name": "Enrolled Bill",
    "bill_version_id": "hr3590-111-enr",
    "urls": {
      "html": "http://www.gpo.gov/fdsys/pkg/BILLS-111hr3590enr/html/BILLS-111hr3590enr.htm",
      "pdf": "http://www.gpo.gov/fdsys/pkg/BILLS-111hr3590enr/pdf/BILLS-111hr3590enr.pdf"
    }
  }
}
```

The **versions** field is an array of information on each version of the bill. This data is sourced from [GPO](http://www.gpo.gov/fdsys/browse/collection.action?collectionCode=BILLS), and is published on a different schedule than most other bill information.

**versions.bill_version_id**<br/>
The unique ID for this bill version. It's the bill's `bill_id` plus the version's `version_code`.

**versions.version_code**<br/>
The short-code for what stage the version of the bill is at. 

**versions.version_name**<br/>
The full name for the stage the version of the bill is at.

**versions.urls**<br/>
A set of HTML, PDF, and XML links (when available) for the official permanent URL of a bill version's text. Our full text search uses the text from the HTML version of a bill.

**last_version**<br/>
Information for only the most recent version of a bill. Useful to limit the size of a request with partial responses.

### Upcoming Debate

```json
{
  "upcoming": [
    {
      "source_type": "senate_daily",
      "url": "http://democrats.senate.gov/2013/01/21/senate-floor-schedule-for-monday-january-21-2013/",
      "chamber": "senate",
      "congress" :113,
      "legislative_day": "2013-01-21",
      "context": "The Senate stands in recess under the provisions of S.Con.Res.3.  The Senate will meet at 11:30am on Monday, January 21, 2013 for the Joint Session for the Inaugural Ceremonies."
    }
  ]
}
```

The **upcoming** field has an array of objects describing when a bill has been scheduled for future debate on the House or Senate floor. Its information is taken from party leadership websites in the [House](http://majorityleader.gov/) and [Senate](http://democrats.senate.gov/), and updated frequently throughout the day.

While this information is official, party leadership in both chambers have unilateral and immediate control over what is scheduled on the floor, and it can change at any time. We do our best to automatically remove entries when a bill has been yanked from the floor schedule.

**upcoming.source_type**<br/>
Where this information is coming from. Currently, the only values are "senate_daily" or "house_daily".

**upcoming.url**<br/>
An official reference URL for this information.

**upcoming.chamber**<br/>
What chamber the bill is scheduled for debate in.

**upcoming.congress**<br/>
What Congress this is occurring in.

**upcoming.legislative_day**<br/>
The date the bill is scheduled for floor debate.

**upcoming.context**<br/>
Some surrounding context of why the bill is scheduled. This is only present for Senate updates right now.

### Becoming Law

```json
{ 
  "enacted_as": {
    "congress": 111,
    "law_type": "public",
    "number": "148"
  }
}
```

If a bill has been enacted into law, the **enacted_as** field contains information about the law number it was assigned. The above information is for [Public Law 111-148](http://www.gpo.gov/fdsys/pkg/PLAW-111publ148/content-detail.html).

\* **enacted_as.congress**<br/>
The Congress in which this bill was enacted into law.

\* **enacted_as.law_type**<br/>
Whether the law is a public or private law. Most laws are public laws; private laws affect individual citizens. "public" or "private".

\* **enacted_as.number**<br/>
The number the law was assigned.