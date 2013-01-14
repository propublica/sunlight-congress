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

<table>
<tr>
<td>[/legislators](legislators.html)</td>
<td>Current legislators' names, IDs, biography, and social media.</td>
</tr><tr>
<td>[/legislators/locate](legislators.html)</td><td>Find representatives and senators for a `latitude`/`longitude` or `zip`.</td>
</tr><tr>
<td>/districts/locate</td><td>Find congressional districts for a `latitude`/`longitude` or `zip`.</td>
</tr><tr>
<td>/committees</td>
<td>Current committees, subcommittees, and their membership.</td>
</tr><tr>
<td>[/bills](bills.html)</td>
<td>Legislation in the House and Senate, back to 2009. Updated daily.</td>
</tr><tr>
<td>[/bills/search](bills.html)</td><td>Full text search over legislation.</td>
</tr><tr>
<td>[/votes](votes.html)</td>
<td>Roll call votes in Congress, back to 2009. Updated within minutes of votes.</td>
</tr><tr>
<td>/floor_updates</td>
<td>To-the-minute updates from the floor of the House and Senate.</td>
</tr><tr>
<td>[/hearings](hearings.html)</td>
<td>Committee hearings in Congress. Updated as hearings are announced.</td>
</tr><tr>
<td>/upcoming_bills</td>
<td>Bills scheduled for debate in the future, as announced by party leadership.</td>
</tr>
</table>

## Parameters

### API Key

All requests to the Congress API require a Sunlight API key. An API key is [free to register](http://services.sunlightlabs.com/accounts/register/) and has no usage limits.

API keys can be provided with a request through the query string:

```text
/bills?apikey=[your_api_key]
```

Or, by setting the key as the value of a `X-APIKEY` HTTP request header.

### Filtering

You can filter on many fields with a simple key/value pair:

```text
/legislators?last_name=Smith
```

```text
/bills?bill_type=hr&congress=112
```

The API will automatically treat numbers as numbers, and "true" and "false" as booleans. Dates and times are compared as strings.

To force the API to treat a value as a string, use quotes:

```text
/legislators?thomas_id="136"
```

See the documentation for a specific data type to see what fields can be filtered on.

### Operators

The API supports 8 operators that can be combined with filters:

**gt** - the field is greater than this value<br/>
**gte** - the fiels is greater than or equal to this value<br/>
**lt** - the field is less than this value<br/>
**lte** - the field is less than or equal to this value<br/>
**not** - the field is not this value<br/>
**exists** - whether the field exists<br/>
**all** - the field is an array that contains all of these values (separated by "|")<br/>
**in** - the field is a string that is one of these values (separated by "|")<br/>

All operators are applied by adding two underscores ("__") after the field name. They cannot be combined.

**Senate votes that got more than 70 ayes**

```text
/votes?breakdown.total.ayes__gte=70&chamber=senate
```

**Bills that got an up or down vote in the House**

```text
/bills?history.house_passage_result__exists=true&chamber=house
```

**Bills cosponsored by both John McCain and Joe Lieberman**

```text
/bills?cosponsor_ids__all=M000303|L000304
```

**Bills sponsored by either John McCain and Joe Lieberman**

```text
/bills?sponsor_id__in=M000303|L000304
```

### Pagination

All results in the Congress API are paginated. Set `per_page` and `page` to control the page size and offset. The maximum `per_page` is 50.

```text
/floor_updates?chamber=house&per_page=50&page=3
```

At the top-level of every response are **count** and **page** fields, with pagination information.

```json
{
count: 163,
page: {
  per_page: 50,
  page: 3,
  count: 50
}
}
```

**count**<br/>
The total number of documents that match the query.

**page.per_page**<br/>
The `per_page` value used to find the response. Defaults to 20.

**page.page**<br/>
The `page` value used to find the response. Defaults to 1.

**page.count**<br/>
The number of actual documents in the response. Can be less than the given `per_page` if there are too few documents.

### Sorting

Sort results by one or more fields with the `order` parameter. `order` is optional, but if no `order` is provided, the order of results is not guaranteed to be predictable.

Append `__asc` or `__desc` to the field names to control sort direction. The default direction is **desc**, because it is expected most queries will sort by a date.

Any field which can be used for filtering may be used for sorting. On full-text search endpoints (URLs ending in `/search`), you may sort by `score` to order by relevancy.

**Most recent bills**

```text
/bills?order=introduced_on
```

**Legislators from each state, sorted by last name within state**

```text
/legislators?order=state__asc,last_name__asc
```

**Most relevant bills matching "health care"**

```text
/bills/search?query="health care"&order=score
```

### Partial responses

You can request specific fields by supplying a comma-separated list of fields as the `fields` parameter.

**Many fields are not returned unless requested.** If you don't supply a `fields` parameter, you will get the most commonly used subset of fields only.

To save on bandwidth, parsing time, and confusion, it's recommended to always specify which fields you will be using.

**Latest vote numbers and their results**

```text
/votes?fields=roll_id,result,breakdown.total
```

```json
{
"results": [
  {
    "result": "Passed",
    "roll_id": "h7-2013"
  },
  {
    "result": "Passed",
    "roll_id": "h3-2013"
  }
  ...
]
}
```

### Search

Provide a `query` parameter to return results the API thinks best match your query. Queries are interpreted as **phrases**.

**Senate hearings matching "environment"**

```text
/hearings?query=environment&chamber=senate
```

**House floor updates matching "committee of the whole"**

```text
/floor_updates?query=committee of the whole&chamber=house
```

## Full text search

Endpoints ending with `/search` that are given a `query` parameter perform full text search. These queries can use some advanced operators. Queries are interpreted as **keywords** (use quotes to form phrases).

**Laws matching "health care" and "medicine"**

```text
/bills/search?query="health care" medicine&history.enacted=true
```

Operators allowed:

* Wildcards: Use `*` as a wildcard within words (e.g. `nanotech*`). Cannot be used within phrases.
* Adjacency: Append `~` and a number to a phrase to allow the words to come within X words of each other. (e.g. `"transparency accountability"~5`)

**Bills matching "freedom of information" and words starting with "accountab"**

```text
/bills/search?query="freedom of information" accountab*
```

**Bills with "transparency" and "accountability" within 5 words of each other**

```text
/bills/search?query="transparency accountability"~5
```


### Highlighting

When performing full text search, you can retrieve highlighted excerpts of where your search matched by using the parameter `highlight=true`. (This will make the request slower, so only use if needed.)

**Recent bills matching "gun control", with highlighting**

```text
/bills/search?query="gun control"&highlight=true&order=introduced_on
```

By default, highlighting is performed with the `<em>` and `</em>` tags. Control these tags by passing start and close tags to the `highlight.tags` parameter. (Disable highlighting altogether by passing only `,`.)

**Bills matching "immigration", highlighted with &lt;b&gt; tags**

```text
/bills/search?query=immigration&highlight=true&highlight.tags=<b>,</b>
```

**Bills matching "immigration", with no highlighting**

```text
/bills/search?query=immigration&highlight=true&highlight.tags=,
```

Control the size of highlighted excerpts with the `highlight.size` parameter. (Note: This doesn't always work; the database makes a best attempt.) The default `highlight.size` is 200.

**Bills matching "drugs", with larger excerpts**

```text
/bills/search?query=drugs&highlight=true&highlight.size=500
```

## Other

### Explain mode

Add an `explain=true` parameter to any API request to return a JSON response with how the API interpreted the query, and database-specific explain information.

This is a convenience for debugging, not a "supported" API feature. Don't make automatic requests with explain mode turned on.

### Bulk Data

Core data for legislators, committees, and bills come from public domain [scrapers](https://github.com/unitedstates/congress) and [bulk data](https://github.com/unitedstates/congress-legislators) at [github.com/unitedstates](https://github.com/unitedstates/). 

The Congress API is not designed for bulk data downloads. Requests are limited to a maximum of 50 per page, and many fields need to be specifically requested. Please use the above resources to collect this data in bulk.

### Planned Features

* All amendments to bills introduced in the House and Senate.
* Draft legislation in the House, as posted to [docs.house.gov](http://docs.house.gov).
* Reports by GAO, CBO, and Congressional committees.

### More APIs

If the Sunlight Congress API doesn't have what you're looking for, check out other Congress APIs:

* [GovTrack Data API](http://www.govtrack.us/developers/api)
* [New York Times Congress API](http://developer.nytimes.com/docs/congress_api)

Or if you're looking for other government data:

* [FederalRegister.gov API](https://www.federalregister.gov/learn/developers) - Official (government-run) API for the activity of the executive branch of the US government. Includes proposed and final regulations, notices, executive orders, and much more.
* [Open States API](http://openstates.org/api/) - US legislative data for all 50 states.
* [Capitol Words API](http://capitolwords.org/api/) - Search speeches of members of Congress (the Congressional Record), and get all sorts of language analysis on frequently used words and phrases.
* [Influence Explorer API](http://data.influenceexplorer.com/api) - Data around federal lobbying, grants, contracts, and state and federal campaign contributions.