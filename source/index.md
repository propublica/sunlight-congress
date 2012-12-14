# Sunlight Congress API

A live JSON API for the people and work of Congress.

## Features

Lots of features and data for members of Congress:

* Look up legislators by location or by zip code.
* Official Twitter, YouTube, and Facebook accounts.
* Committees and subcommittees in Congress, including memberships and rankings.

We also provide Congress' daily work:

* All introduced bills in the House and Senate, and what occurs to them (updated daily).
* Full text search over bills, with powerful Lucene-based query syntax.
* Real time notice of votes, floor activity, and committee hearings, and when bills are scheduled for debate.

All data is served in JSON, and requires a Sunlight API key. An API key is [free to register](http://services.sunlightlabs.com/accounts/register/) and has no usage limits.

We have an [API mailing list](https://groups.google.com/forum/?fromgroups#!forum/sunlightlabs-api-discuss), and can be found on Twitter at [@sunlightlabs](http://twitter.com/sunlightlabs). Bugs and feature requests can be made on [Github Issues](https://github.com/sunlightlabs/congress/issues).


## Methods

The Sunlight Congress API lives at:

```text
http://congress.api.sunlightfoundation.com
```

### Filtering

Most methods filter through paginated lists of documents, that can be sorted and filtered by various fields and operators. Under the hood, these methods use [MongoDB](http://www.mongodb.org/).

<table>
<tr>
<td>[/legislators](#data/legislators)</td>
<td>Current legislators' names, IDs, biography, and social media.</td>
</tr><tr>
<td>/committees</td>
<td>Current Congressional committees, subcommittees, and their membership.</td>
</tr><tr>
<td>/bills</td>
<td>Legislation in the House and Senate, back to 2009. Updated daily.</td>
</tr><tr>
<td>/votes</td>
<td>Roll call votes in Congress, back to 2009. Updated within minutes of votes.</td>
</tr><tr>
<td>/floor_updates</td>
<td>To-the-minute updates from the floor of the House and Senate.</td>
</tr><tr>
<td>/hearings</td>
<td>Committee hearings in Congress. Updated as hearings are announced.</td>
</tr><tr>
<td>/upcoming_bills</td>
<td>Bills scheduled for debate in the future, as announced by party leadership.</td>
</tr><tr>
<td>/videos</td>
<td>Video of the House and Senate floor.</td>
</tr>
</table>

### Geolocation

Look up information by `latitude` and `longitude`, or by a `zip` code. No sorting, pagination, or other filters. Under the hood, these methods use a [modified version](https://github.com/sunlightlabs/pentagon) of the Chicago Tribune's [Boundary Service](https://github.com/newsapps/django-boundaryservice).

<table>
<tr>
<td>/legislators/locate</td><td>Find representatives and senators for a `latitude`/`longitude` or `zip`.</td>
</tr><tr>
<td>/districts/locate</td><td>Find Congressional Districts for a `latitude`/`longitude` or `zip`.</td>
</tr>
</table>


### Text Searching

Execute a full-text search query, using a Lucene-based query string syntax. Under the hood, these methods use [ElasticSearch](http://www.elasticsearch.org/).

<table>
<tr>
<td>/bills/search</td><td>Search the text of bills' most recent versions, back to 2009. Updated daily.</td>
</tr><tr>
<td>/clips/search</td><td>Captions of words from House and Senate video, back to 2009. Updated daily.</td>
</tr>
</table>



## Operators

### Filtering on fields

### Operators

### Pagination

### Ordering

### Partial responses

## Full Text Search

### Query string

### Highlighting

### Scores

## Geolocating

### By latitude and longitude

### By zip code



## Other

### Bulk Data

Core data for legislators, committees, and bills come from public domain [scrapers](https://github.com/unitedstates/congress) and [bulk data](https://github.com/unitedstates/congress-legislators) at [github.com/unitedstates](https://github.com/unitedstates/). 

The Congress API is not designed for bulk data downloads. Requests are limited to a maximum of 50 per page, and many fields need to be specifically requested. Please use the above resources to collect this data.

### Planned Features

* All amendments to bills introduced in the House and Senate.
* Draft legislation in the House, as posted to [docs.house.gov](http://docs.house.gov).
* Reports by GAO, CBO, and Congressional committees.

### Other APIs

If the Sunlight Congress API doesn't have what you're looking for, check out other Congress APIs:

* [GovTrack Data API](http://www.govtrack.us/developers/api)
* [New York Times Congress API](http://developer.nytimes.com/docs/congress_api)

Or if you're looking for other government data:

* [FederalRegister.gov API](https://www.federalregister.gov/learn/developers) - Official (government-run) API for the activity of the executive branch of the US government. Includes proposed and final regulations, notices, executive orders, and much more.
* [Open States API](http://openstates.org/api/) - US legislative data for all 50 states.
* [Capitol Words API](http://capitolwords.org/api/) - Search speeches of members of Congress (the Congressional Record), and get all sorts of language analysis on frequently used words and phrases.
* [Influence Explorer API](http://data.influenceexplorer.com/api) - Data around federal lobbying, grants, contracts, and state and federal campaign contributions.