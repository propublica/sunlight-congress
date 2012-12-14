# Legislators

Data on members of Congress, dating back to 1789. All member information is sourced from [github.com/unitedstates](https://github.com/unitedstates/congress-legislators), which gathers data from official sources through a combination of mostly automated scripts, with some manual review.

If you're looking for **bulk data** on members of Congress, use the bulk data (YAML) files at [github.com/unitedstates](https://github.com/unitedstates/congress-legislators).

## Endpoints

### /legislators

### /legislators/locate

Find members of Congress by location. [Location methods](index.html#location) require a `latitude` and `longitude`, or a `zip` code. There is no pagination, ordering, partial response, or operator support.

This will return both **representatives** and **senators** that represent the given point or zip. For a given `latitude` and `longitude`, this should return up to 1 representative and 2 senators. 

A `zip` code may intersect multiple Congressional districts, so locating by `zip` may return multiple representatives, and possibly more than 2 senators if the zip code crosses state borders.

In general, we [recommend against using zip codes](http://sunlightlabs.com/blog/2012/dont-use-zipcodes/) to look up members of Congress. For one, it's imprecise: a zip code can intersect multiple congressional districts. More importantly, zip codes **are not shapes**. They are lines (delivery routes), and treating them as shapes leads to inaccuracies. Check [our blog post](http://sunlightlabs.com/blog/2012/dont-use-zipcodes/) for more details.

## Fields

### General

<dt>in_office</dt>
<span class="note type">boolean</span>
<span class="note filter">filterable</span>
<dd>
  Whether a legislator is currently holding elected office in Congress.
</dd>

<dt>party</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "R"</span>
<dd>
  First letter of the party this member belongs to.
</dd>

<dt>gender</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "M"</span>
<dd>
  First letter of this member's gender.
</dd>

<dt>state</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "KY"</span>
<dd>
  Two-letter code of the state this member represents.
</dd>

<dt>title</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "Sen"</span>
<dd>
  Title of this member. In the Senate, this is always "Sen". In the House, it is usually "Rep", but can be "Del" or "Com".
</dd>

<dt>chamber</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "senate"</span>
<dd>
  Chamber the member is in. "senate" or "house".
</dd>

<dt>senate_class</dt>
<span class="note type">number</span>
<span class="note filter">filterable</span>
<span class="note example">example: 1</span>
<dd>
  Which senate "class" the member belongs to (1, 2, or 3). Every 2 years, a separate one third of the Senate is elected to a 6-year term. Senators of the same class face election in the same year. Blank for members of the House.
</dd>

### Identifiers

<dt>bioguide_id</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "B000944"</span>
<dd>
  Identifier for this member in various Congressional sources. Originally taken from the Congressional Biographical Directory, but used in many places. If you're going to pick one ID as a Congressperson's unique ID, use this.
</dd>

<dt>thomas_id</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "136"</span>
<dd>
  Identifier for this member as it appears on THOMAS.gov and Congress.gov.
</dd>

<dt>lis_id</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "S307"</span>
<dd>
  Identifier for this member as it appears on some of Congress' data systems (namely [Senate votes](http://www.senate.gov/legislative/LIS/roll_call_votes/vote1122/vote_112_2_00228.xml)).
</dd>

<dt>govtrack_id</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "400050"</span>
<dd>
  Identifier for this member as it appears on [GovTrack.us](http://govtrack.us).
</dd>

<dt>votesmart_id</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "L000551"</span>
<dd>
  Identifier for this member as it appears on [Project Vote Smart](http://votesmart.org/).
</dd>

<dt>opensecrets_id</dt>
<span class="note type">string</span>
<span class="note filter">filterable</span>
<span class="note example">example: "N00003535"</span>
<dd>
  Identifier for this member as it appears on [OpenSecrets](http://www.opensecrets.org).
</dd>

<dt>fec_ids</dt>
<span class="note type">string array</span>
<span class="note filter">filterable</span>
<span class="note example">example: ["S0HI00084"]</span>
<dd>
  A list of identifiers for this member as they appear in filings at the [Federal Election Commission](http://fec.gov/).
</dd>

### Names

### Contact info

### Social Media

### Terms


## Examples

### Legislators at latitude/longitude

### Legislators by zip code

### Legislators by party and chamber

### Legislators with last name

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
  ],
  "count":538,
  "page":{
    "count":1,
    "per_page":1,
    "page":3
  }
}
```