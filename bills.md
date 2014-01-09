---
layout: default
---

* placeholder
{:toc}

# Bills

Data on bills in Congress goes back to 2009, and comes from a mix of sources:

* Scrapers at [github.com/unitedstates](https://github.com/unitedstates/congress) for most data, including core status and history information.
* Bulk data at [GPO's FDSys](http://www.gpo.gov/fdsys/) for version information, and full text.
* The House' [MajorityLeader.gov](http://majorityleader.gov/) and Senate Democrats' [official site](http://democrats.senate.gov/) for notices of upcoming debate.

Feel free to [open a ticket](https://github.com/unitedstates/congress/issues/new) with any bugs or suggestions.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

### /bills

Filter through bills in Congress. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Bills enacted into law in the 113th Congress**

{% highlight text %}
/bills?congress=113&history.enacted=true
{% endhighlight %}

**Active bills, ordered by recent activity**
{% highlight text %}
/bills?history.active=true&order=last_action_at
{% endhighlight %}

**Bills sponsored by Republicans that have been vetoed**

{% highlight text %}
/bills?sponsor.party=R&history.vetoed=true
{% endhighlight %}

**Most recent private laws**

{% highlight text %}
/bills?enacted.law_type=private&order=history.enacted_at
{% endhighlight %}

**Joint resolutions that received a vote in the House and Senate**

{% highlight text %}
/bills?bill_type__in=hjres|sjres&history.house_passage_result__exists=true&history.senate_passage_result__exists=true
{% endhighlight %}

### /bills/search

Search the full text of legislation, and other fields.

The `query` parameter allows wildcards, quoting for phrases, and nearby word operators ([full reference](index.html#full-text-search)) You can also retrieve [highlighted excerpts](index.html#full-text-search/highlighting), and all [normal operators](index.html#parameters/operators) and filters.

This searches the bill's full text, `short_title`, `official_title`, `popular_title`, `nicknames`, `summary`, and `keywords` fields.

**Laws matching "health care"**

{% highlight text %}
/bills/search?query="health care"&history.enacted=true
{% endhighlight %}

**Bills matching "freedom of information" and words starting with "accountab"**

{% highlight text %}
/bills/search?query="freedom of information" accountab*
{% endhighlight %}

**Bills with "transparency" and "accountability" within 5 words of each other, with excerpts**

{% highlight text %}
/bills/search?query="transparency accountability"~5&highlight=true
{% endhighlight %}


## Fields

All examples below are from H.R. 3590 of the 111th Congress, the [Patient Protection and Affordable Care Act](http://www.govtrack.us/congress/bills/111/hr3590) (Obamacare).

**Many fields are not returned unless requested.** You can request specific fields with the `fields` parameter. See the [partial responses](index.html#parameters/partial-responses) documentation for more details.

\* = can be used as a filter

{% highlight json %}
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
{% endhighlight %}

\* **bill_id**
The unique ID for this bill. Formed from the `bill_type`, `number`, and `congress`.

\* **bill_type**
The type for this bill. For the bill "H.R. 4921", the `bill_type` represents the "H.R." part. Bill types can be: **hr**, **hres**, **hjres**, **hconres**, **s**, **sres**, **sjres**, **sconres**.

\* **number**
The number for this bill. For the bill "H.R. 4921", the `number` is 4921.

\* **congress**
The Congress in which this bill was introduced. For example, bills introduced in the "111th Congress" have a `congress` of 111.

\* **chamber**
The chamber in which the bill originated.

\* **introduced_on**
The date this bill was introduced.

\* **last_action_at**
The date or time of the most recent official action. In the rare case that there are no official actions, this field will be set to the value of `introduced_on`.

\* **last_vote_at**
The date or time of the most recent vote on this bill.

\* **last_version_on**
The date the last version of this bill was published. This will be set to the `introduced_on` date until an official version of the bill's text is published.

### Titles

{% highlight json %}
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
{% endhighlight %}

**official_title**
The current official title of a bill. Official titles are sentences. Always present. Assigned at introduction, and can be revised any time.

**short_title**
The current shorter, catchier title of a bill. About half of bills get these, and they can be assigned any time.

**popular_title**
The current popular handle of a bill, as denoted by the Library of Congress. They are rare, and are assigned by the LOC for particularly ubiquitous bills. They are non-capitalized descriptive phrases. They can be assigned any time.

**titles**
A list of all titles ever assigned to this bill, with accompanying data.

**titles.as**
The state the bill was in when assigned this title.

**titles.title**
The title given to the bill.

**titles.type**
The type of title this is. "official", "short", or "popular".

### Nicknames

{% highlight json %}
{
  "nicknames": [
    "obamacare",
    "ppaca"
  ]
}
{% endhighlight %}

\* **nicknames**
An array of common nicknames for a bill that don't appear in official data. These nicknames are sourced from a public dataset at [unitedstates/bill-nicknames](https://github.com/unitedstates/bill-nicknames), and will only appear for a tiny fraction of bills. In the future, we plan to auto-generate acronyms from bill titles and add them to this array.

### Summary and keywords

{% highlight json %}
{
  "keywords": [
    "Abortion",
    "Administrative law and regulatory procedures",
    "Adoption and foster care",
    ...
  ],

  "summary": "Patient Protection and Affordable Care Act - Title I: Quality, Affordable Health Care for All Americans...",

  "summary_short": "Patient Protection and Affordable Care Act - Title I: Quality, Affordable Health Care for All Americans..."
}
{% endhighlight %}

\* **keywords**
A list of official keywords and phrases assigned by the Library of Congress. These keywords can be used to group bills into tags or topics, but there are many of them (1,023 unique keywords since 2009, as of late 2012), and they are not grouped into a hierarchy. They can be assigned or revised at any time after introduction.

**summary**
An official summary written and assigned at some point after introduction by the Library of Congress. These summaries are generally more accessible than the text of the bill, but can still be technical. The LOC does not write summaries for all bills, and when they do can assign and revise them at any time.

**summary_short**
The official summary, but capped to 1,000 characters (and an ellipse). Useful when you want to show only the first part of a bill's summary, but don't want to download a potentially large amount of text.

### URLs

{% highlight json %}
{
  "urls": {
    "congress" :"http://beta.congress.gov/bill/111th/house-bill/3590",
    "govtrack" :"http://www.govtrack.us/congress/bills/111/hr3590",
    "opencongress" :"http://www.opencongress.org/bill/111-h3590/show"
  }
}
{% endhighlight %}

**urls**
An object with URLs for this bill's landing page on Congress.gov, GovTrack.us, and OpenCongress.org.

### History

{% highlight json %}
{
  "history": {
    "active": true,
    "active_at": "2009-10-07T18:35:00Z",
    "house_passage_result": "pass",
    "house_passage_result_at": "2010-03-22T02:48:00Z",
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
{% endhighlight %}

The **history** field includes useful flags and dates/times in a bill's life. The above is a real-life example of H.R. 3590 - not all fields will be present for every bill.

Time fields can hold either dates or times - Congress is inconsistent about providing specific timestamps.

\* **history.active**
Whether this bill has had any action beyond the standard action all bills get (introduction, referral to committee, sponsors' introductory remarks). Only a small percentage of bills get this additional activity.

\* **history.active_at**
If this bill got any action beyond initial introduction, the date or time of the first such action. This field will stay constant even as further action occurs. For the time of the most recent action, look to the `last_action_at` field.

\* **history.house_passage_result**
The result of the last time the House voted on passage. Only present if this vote occurred. "pass" or "fail".

\* **history.house_passage_result_at**
The date or time the House last voted on passage. Only present if this vote occurred.

\* **history.senate_cloture_result**
The result of the last time the Senate voted on cloture. Only present if this vote occurred. "pass" or "fail".

\* **history.senate_cloture_result_at**
The date or time the Senate last voted on cloture. Only present if this vote occurred.

\* **history.senate_passage_result**
The result of the last time the Senate voted on passage. Only present if this vote occurred. "pass" or "fail".

\* **history.senate_passage_result_at**
The date or time the Senate last voted on passage. Only present if this vote occurred.

\* **history.vetoed**
Whether the bill has been vetoed by the President. Always present.

\* **history.vetoed_at**
The date or time the bill was vetoed by the President. Only present if this happened.

\* **history.house_override_result**
The result of the last time the House voted to override a veto. Only present if this vote occurred. "pass" or "fail".

\* **history.house_override_result_at**
The date or time the House last voted to override a veto. Only present if this vote occurred.

\* **history.senate_override_result**
The result of the last time the Senate voted to override a veto. Only present if this vote occurred. "pass" or "fail".

\* **history.senate_override_result_at**
The date or time the Senate last voted to override a veto. Only present if this vote occurred.

\* **history.awaiting_signature**
Whether the bill is currently awaiting the President's signature. Always present.

\* **history.awaiting_signature_since**
The date or time the bill began awaiting the President's signature. Only present if this happened.

\* **history.enacted**
Whether the bill has been enacted into law. Always present.

\* **history.enacted_at**
The date or time the bill was enacted into law. Only present if this happened.


### Actions

{% highlight json %}
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
      "text": "Became Public Law No: 111-148.",
      "references": []
    }
  ],
  "last_action": {
    "type": "enacted",
    "acted_at": "2010-03-23",
    "text": "Became Public Law No: 111-148.",
    "references": []
  }
}
{% endhighlight %}

The **actions** field has a list of all official activity that has occurred to a bill. All fields are parsed out of non-standardized sentence text, so mistakes and omissions are possible.

**actions.type**
The type of action. Always present. Can be "action" (generic), "vote" (passage vote), "vote-aux" (cloture vote), "vetoed", "topresident", and "enacted". There can be other values, but these are the only ones we support.

**actions.acted_at**
The date or time the action occurred. Always present.

**actions.text**
The official text that describes this action. Always present.

**actions.committees**
A list of subobjects containing `committee_id` and `name` fields for any committees referenced in an action. Will be missing if no committees are mentioned.

**actions.references**
A list of references to the Congressional Record that this action links to.

**actions.chamber**
If the action is a vote, which chamber this vote occured in. "house" or "senate".

**actions.vote_type**
If the action is a vote, this is the type of vote. "vote", "vote2", "cloture", or "pingpong".

**actions.how**
If the action is a vote, how the vote was taken. Can be "roll", "voice", or "Unanimous Consent".

**actions.result**
If the action is a vote, the result. "pass" or "fail".

**actions.roll_id**
If the action is a roll call vote, the ID of the roll call.

**last_action**
The most recent action.

### Votes

{% highlight json %}
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
{% endhighlight %}

The **votes** array is identical to the `actions` array, but limited to actions that are votes.


### Sponsorships

{% highlight json %}
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
  "cosponsors_count": 90,
  "cosponsors": [
    {
      "sponsored_on": "2009-09-17",
      "legislator": {
        "bioguide_id": "B000287",
        "in_office": true,
        "last_name": "Becerra"
        ...
      }
    },
    {
      "sponsored_on": "2009-09-17",
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
  "withdrawn_cosponsors": [],
  "withdrawn_cosponsors_count": 0
}
{% endhighlight %}

\* **sponsor_id**
The bioguide ID of the bill's sponsoring [legislator](legislators.html), if there is one. It is possible, but rare, to have bills with no sponsor.

**sponsor**
An object with most simple [legislator fields](legislators.html#fields) for the bill's sponsor, if there is one.

\* **cosponsor_ids**
An array of bioguide IDs for each cosponsor of the bill. Bills do not always have cosponsors.

\* **cosponsors_count**
The number of active cosponsors of the bill.

**cosponsors.sponsored_on**
When a legislator signed on as a cosponsor of the legislation.

**cosponsors.legislator**
An object with most simple [legislator fields](legislators.html#fields) for that cosponsor.

\* **withdrawn_cosponsor_ids**
An array of bioguide IDs for each legislator who has withdrawn their cosponsorship of the bill.

\* **withdrawn_cosponsors_count**
The number of withdrawn cosponsors of the bill.

**withdrawn_cosponsors.withdrawn_on**
The date the legislator withdrew their cosponsorship of the bill.

**withdrawn_cosponsors.sponsored_on**
The date the legislator originally cosponsored the bill.

**withdrawn_cosponsors.legislator**
An object with most simple [legislator fields](legislators.html#fields) for that withdrawn cosponsor.

### Committees

{% highlight json %}
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
{% endhighlight %}

\* **committee_ids**
A list of IDs of [committees](committees.html) related to this bill.

**committees.activity**
A list of relationships that the committee has to the bill, as they appear on [THOMAS.gov](http://thomas.loc.gov). The most common is "referral", which means a committee has jurisdiction over this bill.

### Related Bills

{% highlight json %}
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
{% endhighlight %}

\* **related_bill_ids**
A list of IDs of bills that the Library of Congress has declared "related". Relations can be pretty loose, use this field with caution.

### Versions

{% highlight json %}
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
{% endhighlight %}

The **versions** field is an array of information on each version of the bill. This data is sourced from [GPO](http://www.gpo.gov/fdsys/browse/collection.action?collectionCode=BILLS), and is published on a different schedule than most other bill information.

**versions.bill_version_id**
The unique ID for this bill version. It's the bill's `bill_id` plus the version's `version_code`.

**versions.version_code**
The short-code for what stage the version of the bill is at.

**versions.version_name**
The full name for the stage the version of the bill is at.

**versions.urls**
A set of HTML, PDF, and XML links (when available) for the official permanent URL of a bill version's text. Our full text search uses the text from the HTML version of a bill.

**last_version**
Information for only the most recent version of a bill. Useful to limit the size of a request with partial responses.

### Upcoming Debate

{% highlight json %}
{
  "upcoming": [
    {
      "source_type": "senate_daily",
      "url": "http://democrats.senate.gov/2013/01/21/senate-floor-schedule-for-monday-january-21-2013/",
      "chamber": "senate",
      "congress" :113,
      "range": "day",
      "legislative_day": "2013-01-21",
      "context": "The Senate stands in recess under the provisions of S.Con.Res.3.  The Senate will meet at 11:30am on Monday, January 21, 2013 for the Joint Session for the Inaugural Ceremonies."
    }
  ]
}
{% endhighlight %}

The **upcoming** field has an array of objects describing when a bill has been scheduled for future debate on the House or Senate floor. Its information is taken from party leadership websites in the [House](http://majorityleader.gov/) and [Senate](http://democrats.senate.gov/), and updated frequently throughout the day.

While this information is official, party leadership in both chambers have unilateral and immediate control over what is scheduled on the floor, and it can change at any time. We do our best to automatically remove entries when a bill has been yanked from the floor schedule.

**upcoming.source_type**
Where this information is coming from. Currently, the only values are "senate_daily" or "house_daily".

**upcoming.range**
How precise this information is. "day", "week", or null. See more details on this field in the [/upcoming_bills](upcoming_bills.html) documentation.

**upcoming.url**
An official reference URL for this information.

**upcoming.chamber**
What chamber the bill is scheduled for debate in.

**upcoming.congress**
What Congress this is occurring in.

**upcoming.legislative_day**
The date the bill is scheduled for floor debate.

**upcoming.context**
Some surrounding context of why the bill is scheduled. This is only present for Senate updates right now.

### Becoming Law

{% highlight json %}
{
  "enacted_as": {
    "congress": 111,
    "law_type": "public",
    "number": 148
  }
}
{% endhighlight %}

If a bill has been enacted into law, the **enacted_as** field contains information about the law number it was assigned. The above information is for [Public Law 111-148](http://www.gpo.gov/fdsys/pkg/PLAW-111publ148/content-detail.html).

\* **enacted_as.congress**
The Congress in which this bill was enacted into law.

\* **enacted_as.law_type**
Whether the law is a public or private law. Most laws are public laws; private laws affect individual citizens. "public" or "private".

\* **enacted_as.number**
The number the law was assigned.
