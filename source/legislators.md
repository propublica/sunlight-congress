# Legislators

Data on members of Congress, dating back to 1789. All member information is sourced from the bulk data at [github.com/unitedstates](https://github.com/unitedstates/congress-legislators).

## Methods

All requests require a valid [API key](index.html#apikey).

### /legislators/locate

Find members of Congress by a `latitude` and `longitude`, or a `zip` code. There is no support for operators, ordering, or partial responses.

**By latitude/longitude**

```text
/legislators/locate?latitude=42.96&longitude=-108.09
```

This will return both representatives and senators that represent the given point or zip. For a given `latitude` and `longitude`, this should return up to 1 representative and 2 senators. 

**By zip code**

```text
/legislators/locate?zip=11216
```

A `zip` code may intersect multiple Congressional districts, so locating by `zip` may return multiple representatives, and possibly more than 2 senators if the zip code crosses state borders.

In general, we [recommend against using zip codes](http://sunlightlabs.com/blog/2012/dont-use-zipcodes/) to look up members of Congress. For one, it's imprecise: a zip code can intersect multiple congressional districts. More importantly, zip codes *are not shapes*. They are lines (delivery routes), and treating them as shapes leads to inaccuracies.

### /legislators

Search and filter for members of Congress. 

**Filtering on fields**

```text
/legislators?party=D&chamber=senate
```

Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#operators) apply.

By default, all requests will return *currently serving members*, but you can override this by supplying `in_office=false`.

**Searching by a string**

```text
/legislators?query=mcconnell
```

This will match against name fields: `first_name`, `last_name`, `middle_name`, `nickname`, `other_names.last`

**Disabling pagination**

You can turn off pagination for requests to `/legislators`, but doing so will force a filter of `in_office=true` (that cannot be overridden).

```text
/legislators?per_page=all
```


## Fields

\* = can be used as a filter

\* **in_office** (boolean)<br/>
Whether a legislator is currently holding elected office in Congress.

\* **party** (string)</br>
First letter of the party this member belongs to. "R", "D", or "I".

\* **gender** (string)<br/>
First letter of this member's gender. "M" or "F".

\* **state** (string)<br/>
Two-letter code of the state this member represents.

\* **state_name** (string)<br/>
The full state name of the state this member represents.

\* **title** (string)<br/>
Title of this member. "Sen", "Rep", "Del", or "Com".

\* **chamber** (string)<br/>
Chamber the member is in. "senate" or "house".

**senate_class** (number)</br>
Which senate "class" the member belongs to (1, 2, or 3). Every 2 years, a separate one third of the Senate is elected to a 6-year term. Senators of the same class face election in the same year. Blank for members of the House.

**birthday** (date)</br>
The date of this legislator's birthday.

\* **term_start** (date)<br/>
The date a member's current term started.

\* **term_end** (date)<br/>
The date a member's current term will end.

### Identifiers

\* **bioguide_id** (string)<br/>
Identifier for this member in various Congressional sources. Originally taken from the [Congressional Biographical Directory](http://bioguide.congress.gov), but used in many places. If you're going to pick one ID as a Congressperson's unique ID, use this.

\* **thomas_id** (string)<br/>
Identifier for this member as it appears on [THOMAS.gov](http://thomas.loc.gov) and [Congress.gov](http://congress.gov).

\* **lis_id** (string)<br/>
Identifier for this member as it appears on some of Congress' data systems (namely [Senate votes](http://www.senate.gov/legislative/LIS/roll_call_votes/vote1122/vote_112_2_00228.xml)).

\* **govtrack_id** (string)<br/>
Identifier for this member as it appears on [GovTrack.us](http://govtrack.us).

\* **votesmart_id** (string)<br/>
Identifier for this member as it appears on [Project Vote Smart](http://votesmart.org/).

\* **opensecrets_id** (string)<br/>
Identifier for this member as it appears on [OpenSecrets](http://www.opensecrets.org).

\* **fec_ids** (string)<br/>
A list of identifiers for this member as they appear in filings at the [Federal Election Commission](http://fec.gov/).

### Names

\* **first_name** (string)<br/>
The member's first name. This may or may not be the name they are usually called.

\* **nickname** (string)<br/>
The member's nickname. If present, usually safe to assume this is the name they go by.

\* **last_name** (string)<br/>
The member's last name.

\* **middle_name** (string)<br/>
The member's middle name, if they have one.

\* **name_suffix** (string)<br/>
A name suffix, if the member uses one. For example, "Jr." or "III".

### Contact info

**phone** (string)<br/>
Phone number of the members's DC office.

**fax** (string)<br/>
Fax number of the members's DC office.

**office** (string)<br/>
Office number for the member's DC office.

**website** (string)<br/>
Official legislative website.

**contact_form** (string)<br/>
URL to their official contact form.

### Social Media

**twitter_id** (string)<br/>
The Twitter *username* for a member's official legislative account. This field does not contain the handles of campaign accounts.

**youtube_id** (string)<br/>
The YouTube *username* for a member's official legislative account. This field does not contain the handles of campaign accounts.

**facebook_id** (string)<br/>
The Facebook *username or ID* for a member's official legislative Facebook presence. ID numbers and usernames can be used interchangeably in Facebook's URLs and APIs. The referenced account may be either a Facebook Page or a user account.

### Terms

An array of information for each term the member has served, from oldest to newest. Example:

```json
{
  "terms": [{
    "start": "2013-01-03",
    "end": "2019-01-03",
    "state": "NJ",
    "party": "D",
    "class": 1,
    "title": "Sen",
    "chamber": "senate"
  }]
}
```

**terms.start** (date)<br/>
The date this term began.

**terms.end** (date)<br/>
The date this term ended, or will end.

**terms.state** (string)<br/>
The two-letter state code this member was serving during this term.

**terms.party** (string)<br/>
The party this member belonged to during this term.

**terms.title** (string)<br/>
The title this member had during this term. "Rep", "Sen", "Del", or "Com".

**terms.chamber** (string)<br/>
The chamber this member served in during this term. "house" or "senate".

**terms.class** (number)<br/>
The Senate class this member belonged to during this term, if they served in the Senate. Determines in which cycle they run for re-election. 1, 2, or 3.


### Example legislator

```json
{
  "results":[
    {
      "in_office":true,

      "bioguide_id":"B000944",
      "thomas_id":"136",
      "govtrack_id":"400050",
      "votesmart_id":"27018",
      "crp_id":"N00003535",
      "lis_id":"S307",
      
      "first_name":"Sherrod",
      "nickname":null,
      "last_name":"Brown",
      "middle_name":null,
      "name_suffix":null,

      "state":"OH",
      "district":null,
      "party":"D",
      "gender":"M",
      "title":"Sen",
      "chamber":"senate",
      "senate_class":1,
      
      "phone":"202-224-2315",
      "website":"http://brown.senate.gov/",
      "office":"713 Hart Senate Office Building",
      "contact_form":"http://www.brown.senate.gov/contact/",

      "twitter_id":"SenSherrodBrown",
      "youtube_id":"SherrodBrownOhio",
      "facebook_id":"109453899081640",

      "term_start":"2007-01-04",
      "term_end":"2012-12-31",

      "terms":[
        {
          "start":"2005-01-04",
          "end":"2006-12-09",
          "state":"OH",
          "district":13,
          "party":"D",
          "title":"Rep",
          "chamber":"house"
        },
        {
          "start":"2007-01-04",
          "end":"2012-12-31",
          "state":"OH",
          "class":1,
          "party":"D",
          "title":"Sen",
          "chamber":"senate"
        }
      ]
    }
  ]
}
```