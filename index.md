---
layout: default
redirect_from: /not-index
---

* placeholder
{:toc}

A live JSON API for the people and work of Congress, provided by the [Sunlight Foundationn](http://sunlightfoundation.com).

* Look up members of Congress by location or by zip code.
* Official Twitter, YouTube, and Facebook accounts.
* The daily work of Congress: bills, amendments, nominations.
* The live activity of Congress: past and future votes, floor activity, hearings.

All requests require a [Sunlight API key](http://services.sunlightlabs.com/accounts/register/). An API key is free, and has no limits or use restrictions.

We have an [API mailing list](https://groups.google.com/forum/?fromgroups#!forum/sunlightlabs-api-discuss), and can be found on Twitter at [@sunlightlabs](https://twitter.com/sunlightlabs). Report bugs and request features on [GitHub Issues](https://github.com/sunlightlabs/congress/issues).


## Using the API

{% highlight text %}
https://congress.api.sunlightfoundation.com/[method]
{% endhighlight %}

Encryption (`https://`) is used by default, and **[strongly recommended](http://sunlightfoundation.com/blog/2014/01/28/encrypting-our-congress-api-and-protecting-your-location/)**.

### Methods

Path | Description
|:------------------------------|-------------------------|
[/legislators](legislators.html) | Current legislators' names, IDs, biography, and social media.
[/legislators/locate](legislators.html) | Find representatives and senators for a `latitude`/`longitude` or `zip`.
[/districts/locate](districts.html) | Find congressional districts for a `latitude`/`longitude` or `zip`.
[/committees](committees.html) | Current committees, subcommittees, and their membership.
[/bills](bills.html) | Legislation in the House and Senate, back to 2009. Updated daily.
[/bills/search](bills.html) | Full text search over legislation.
[/amendments](amendments.html) | Amendments in the House and Senate, back to 2009. Updated daily.
[/nominations](nominations.html) | Presidential nominations before the Senate, back to 2009. Updated daily.
[/votes](votes.html) | Roll call votes in Congress, back to 2009. Updated within minutes of votes.
[/floor_updates](floor_updates.html) | To-the-minute updates from the floor of the House and Senate.
[/hearings](hearings.html) | Committee hearings in Congress. Updated as hearings are announced.
[/upcoming_bills](upcoming_bills.html) | Bills scheduled for debate in the future, as announced by party leadership.


### Status endpoint

If you wish to check the status of the API, [visit the root](https://congress.api.sunlightfoundation.com) (no API key required):

{% highlight bash %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

If everything's up, you'll get a 200 and the following JSON:

{% highlight json %}
{
  "status": 200,
  "message": "I live!",
  "documentation": "http://sunlightlabs.github.io/congress/",
  "code": "https://github.com/sunlightlabs/congress",
  "report_bugs": "https://github.com/sunlightlabs/congress/issues",
  "more_apis": "http://sunlightfoundation.com/api/"
}
{% endhighlight %}

## Parameters

### API Key

All requests to the Congress API require a Sunlight API key. An API key is [free to register](http://services.sunlightlabs.com/accounts/register/) and has no usage limits.

API keys can be provided with a request through the query string:

{% highlight text %}
/legislators?apikey=[your_api_key]
{% endhighlight %}

Or, by setting the key as the value of an `X-APIKEY` HTTP request header.

### Partial responses

You can request specific fields by supplying a comma-separated list of fields as the `fields` parameter.

**Many fields are not returned unless requested.** If you don't supply a `fields` parameter, you will get the most commonly used subset of fields only.

To save on bandwidth, parsing time, and confusion, it's recommended to always specify which fields you will be using.

**Latest vote numbers and their results**

{% highlight text %}
/votes?fields=roll_id,result,breakdown.total
{% endhighlight %}

{% highlight json %}
"results": [
  {
    "breakdown": {
      "total": {
        "Yea": 222,
        "Nay": 190,
        "Not Voting": 19,
        "Present": 0
      }
    },
    "result": "Passed",
    "roll_id": "h43-2013"
  },
  {
    "breakdown": {
      "total": {
        "Yea": 261,
        "Nay": 154,
        "Not Voting": 16,
        "Present": 0
      }
    },
    "result": "Passed",
    "roll_id": "h44-2013"
  }
  ...
]
{% endhighlight %}

### Filtering

You can filter on many fields with a simple key/value pair:

{% highlight text %}
/legislators?last_name=Smith
{% endhighlight %}

{% highlight text %}
/bills?bill_type=hr&congress=112
{% endhighlight %}

The API will automatically treat numbers as numbers, and "true" and "false" as booleans. Dates and times are compared as strings.

To force the API to treat a value as a string, use quotes:

{% highlight text %}
/legislators?thomas_id="01501"
{% endhighlight %}

See the documentation for a specific data type to see what fields can be filtered on.

### Operators

The API supports 8 operators that can be combined with filters:

* **gt** - the field is greater than this value
* **gte** - the field is greater than or equal to this value
* **lt** - the field is less than this value
* **lte** - the field is less than or equal to this value
* **not** - the field is not this value
* **all** - the field is an array that contains all of these values (separated by `|`)
* **in** - the field is a string that is one of these values (separated by `|`)
* **nin** - the field is a string that is *not* one of these values (separated by `|`)
* **exists** - the field is both present and non-null (supply `true` or `false`)

All operators are applied by adding two underscores (`__`) after the field name. They cannot be combined.

**Senate votes that got more than 70 Yea votes**

{% highlight text %}
/votes?breakdown.total.Yea__gte=70&chamber=senate
{% endhighlight %}

**Bills that got an up or down vote in the House**

{% highlight text %}
/bills?history.house_passage_result__exists=true&chamber=house
{% endhighlight %}

**Bills cosponsored by both John McCain and Joe Lieberman**

{% highlight text %}
/bills?cosponsor_ids__all=M000303|L000304
{% endhighlight %}

**Bills sponsored by either John McCain or Joe Lieberman**

{% highlight text %}
/bills?sponsor_id__in=M000303|L000304
{% endhighlight %}

### Pagination

All results in the Congress API are paginated. Set `per_page` and `page` to control the page size and offset. The maximum `per_page` is 50.

{% highlight text %}
/floor_updates?chamber=house&per_page=50&page=3
{% endhighlight %}

At the top-level of every response are **count** and **page** fields, with pagination information.

{% highlight json %}
"count": 163,
"page": {
  "per_page": 50,
  "page": 3,
  "count": 50
}
{% endhighlight %}

**count**
The total number of documents that match the query.

**page.per_page**
The `per_page` value used to find the response. Defaults to 20.

**page.page**
The `page` value used to find the response. Defaults to 1.

**page.count**
The number of actual documents in the response. Can be less than the given `per_page` if there are too few documents.

### Sorting

Sort results by one or more fields with the `order` parameter. `order` is optional, but if no `order` is provided, the order of results is not guaranteed to be predictable.

Append `__asc` or `__desc` to the field names to control sort direction. The default direction is **desc**, because it is expected most queries will sort by a date.

Any field which can be used for filtering may be used for sorting. On full-text search endpoints (URLs ending in `/search`), you may sort by `score` to order by relevancy.

**Most recent bills**

{% highlight text %}
/bills?order=introduced_on
{% endhighlight %}

**Legislators from each state, sorted by last name within state**

{% highlight text %}
/legislators?order=state__asc,last_name__asc
{% endhighlight %}

**Most relevant bills matching "health care"**

{% highlight text %}
/bills/search?query="health care"&order=score
{% endhighlight %}

### Client-side support

The Congress API supports [CORS](http://enable-cors.org/) for all domains, so requests using any [modern JavaScript library](http://jquery.com/) inside [any modern browser](http://enable-cors.org/client.html) should Just Work.

If CORS isn't an option, you can provide a `callback` parameter to wrap the results in a JavaScript function, suitable for use with [JSONP](http://en.wikipedia.org/wiki/JSONP). This can be used to make cross-domain requests to the Congress API within the browser, when CORS is not supported.

For example:

{% highlight text %}
/legislators?last_name=Reid&callback=myCallback
{% endhighlight %}

will return:

{% highlight javascript %}
myCallback({
  "results": [
    {
      "bioguide_id": "R000146",
      "chamber": "senate",
      "last_name": "Reid"
      ...
    }
  ],
  "count": 1,
  "page": {
    "count": 1,
    "per_page": 20,
    "page": 1
  }
});
{% endhighlight %}

### Basic search

Provide a `query` parameter to return results the API thinks best match your query. Queries are interpreted as *phrases*.

**Senate hearings matching "environment"**

{% highlight text %}
/hearings?query=environment&chamber=senate
{% endhighlight %}

**House floor updates matching "committee of the whole"**

{% highlight text %}
/floor_updates?query=committee of the whole&chamber=house
{% endhighlight %}

### Explain mode

Add an `explain=true` parameter to any API request to return a JSON response with how the API interpreted the query, and database-specific explain information.

This is a convenience for debugging, not a "supported" API feature. Don't make automatic requests with explain mode turned on.

### RSS support (experimental)

Some endpoints support [RSS](https://en.wikipedia.org/wiki/RSS) output, in an XML format. This support is **experimental**, could change, and may have bugs. An API key is still required.

Enable RSS by passing `format=rss`, like so:

{% highlight text %}
/bills?format=rss
{% endhighlight %}

The `<item>` fields in the response will look something like:

{% highlight xml %}
<item>
  <title>Establishing the budget for the United States Government for fiscal year 2015...</title>
  <description>
    <![CDATA[Sets forth the congressional budget for the federal government for FY2015...]]>
  </description>
  <link>http://beta.congress.gov/bill/113th/house-concurrent-resolution/96</link>
  <guid isPermaLink="false">hconres96-113</guid>
  <pubDate>Fri, 04 Apr 2014 00:00:00 -0400</pubDate>
</item>
{% endhighlight %}

The following endpoints support RSS:

* [/bills](bills.html#rss) and [/bills/search](bills.html#rss)
* [/votes](votes.html#rss)
* [/upcoming_bills](upcoming_bills.html#rss)

RSS output is, by the spec's design, limited to a small subset of generic fields. You will only get RSS' most basic fields:

* `<title>`
* `<description>`
* `<pubDate>`
* `<guid>`
* `<link>`

Each endpoint defines the best default database fields it can map to those RSS fields. See each supported endpoint's documentation for what fields are RSS-mapped by default.

However, you can override those defaults with `rss.[field]` parameters that point to the field you'd like to be mapped instead.

For example, `/bills` maps bills' `introduced_on` field to RSS' `<pubDate>` field on output. You can override that with:

{% highlight text %}
/bills?format=rss&order=history.enacted_at&rss.pubDate=history.enacted_at
{% endhighlight %}

That will populate `<pubDate>` with the contents of `history.enacted_at` for each bill.

Some notes:

* `<pubDate>` will always attempt to parse the field and produce a date.
* `<description>` will always wrap its value in a `CDATA` block, as in the above example.
* If a field is missing or is `null`, the value populated in RSS will be `"(missing)"`.
* Though you can specify subfields, like `history.enacted_at`, with the dot operator, support in RSS output is limited to direct subkeys. In other words, there can be *no arrays* in the subfield path.

## Full text search

Endpoints ending with `/search` that are given a `query` parameter perform full text search. These queries can use some advanced operators. Queries are interpreted as *keywords* (use quotes to form phrases).

**Laws matching "health care" and "medicine"**

{% highlight text %}
/bills/search?query="health care" medicine&history.enacted=true
{% endhighlight %}

Operators allowed:

* Wildcards: Use `*` as a wildcard within words (e.g. `nanotech*`). Cannot be used within phrases.
* Adjacency: Append `~` and a number to a phrase to allow the words to come within X words of each other. (e.g. `"transparency accountability"~5`)

**Bills matching "freedom of information" and words starting with "accountab"**

{% highlight text %}
/bills/search?query="freedom of information" accountab*
{% endhighlight %}

**Bills with "transparency" and "accountability" within 5 words of each other**

{% highlight text %}
/bills/search?query="transparency accountability"~5
{% endhighlight %}


### Highlighting

When performing full text search, you can retrieve highlighted excerpts of where your search matched by using the parameter `highlight=true`. (This will make the request slower, so only use if needed.)

**Recent bills matching "gun control", with highlighting**

{% highlight text %}
/bills/search?query="gun control"&highlight=true&order=introduced_on
{% endhighlight %}

By default, highlighting is performed with the `<em>` and `</em>` tags. Control these tags by passing start and close tags to the `highlight.tags` parameter. (Disable the highlighting of search terms altogether, leaving only a plain text excerpt, by passing a lone comma, `,`.)

**Bills matching "immigration", with excerpts highlighted with &lt;b&gt; tags**

{% highlight text %}
/bills/search?query=immigration&highlight=true&highlight.tags=<b>,</b>
{% endhighlight %}

**Bills matching "immigration", with excerpts with no highlighting**

{% highlight text %}
/bills/search?query=immigration&highlight=true&highlight.tags=,
{% endhighlight %}

Control the size of highlighted excerpts with the `highlight.size` parameter. (Note: This doesn't always work; the database makes a best attempt.) The default `highlight.size` is 200.

**Bills matching "drugs", with larger excerpts**

{% highlight text %}
/bills/search?query=drugs&highlight=true&highlight.size=500
{% endhighlight %}

## Bulk Data

We provide some bulk data for direct download, separately. The Congress API as documented above is not designed for retrieving bulk data -- requests are limited to a maximum of 50 per page, and many fields need to be specifically requested. If you need data in bulk, please use these resources rather than fetching it all through the API.

### Legislator spreadsheet

We offer a CSV of basic legislator information for [direct download here](http://unitedstates.sunlightfoundation.com/legislators/legislators.csv).

It includes basic information about names, positions, biographical details, contact information, social media accounts, and identifiers for various public databases.

It contains current information only - it does not include a legislator's history of changes to name, party, chamber, etc.

### Zip Codes to Congressional Districts

We provide a CSV connecting Zip Code Tabulation Areas (ZCTAs) to congressional districts for [direct download here](http://assets.sunlightfoundation.com/data/districts.csv).

This is the data we use in our [/legislators/locate](legislators.html) and [/districts/locate](districts.html) endpoints when a `zip` is provided. These are technically not zip codes, but ZCTAs: all of our [warnings and caveats](http://sunlightlabs.com/blog/2012/dont-use-zipcodes/) about using ZCTAs apply.

### Legislator Photos

We help maintain a repository of public domain images of members of Congress, located at:

[https://github.com/unitedstates/images](https://github.com/unitedstates/images)

Images are collected primarily from the Government Printing Office's [Member Guide](http://memberguide.gpo.gov), and hosted at predictable URLs, using the member of Congress' Bioguide ID.

See the [URL documentation](https://github.com/unitedstates/images#using-the-photos) for complete details.

**Are we missing some photos?** [Raise the issue](https://github.com/unitedstates/images/issues/new) and let us know - we [welcome contributions](https://github.com/unitedstates/images/blob/gh-pages/CONTRIBUTING.md)!

### Core Information

Core information for legislators, committees, and bills come from public domain scrapers and bulk data at [github.com/unitedstates](https://github.com/unitedstates/).

* [Scrapers for bulk bill data](https://github.com/unitedstates/congress) in JSON from THOMAS.gov, 1973-present.
* [Legislator and committee bulk data](https://github.com/unitedstates/congress-legislators) in YAML from various sources, 1789-present.
* [Popular nicknames for bills](https://github.com/unitedstates/bill-nicknames) in CSV, manually updated and unofficial (e.g. "obamacare").

## Client Libraries

If you've written a client library, please tweet at [@sunlightlabs](https://twitter.com/sunlightlabs) or [email us](mailto:api@sunlightfoundation.com) so we can link to it here.

* Node: Matthew Chase Whittemore's [sunlight-congress-api](https://npmjs.org/package/sunlight-congress-api) (unofficial)
* Ruby: Erik Michaels-Ober's [congress gem](http://rubygems.org/gems/congress) (unofficial)
* PHP: lobostome's [FurryBear](https://github.com/lobostome/FurryBear) (unofficial)
* Python: [python-sunlight](https://github.com/sunlightlabs/python-sunlight) ([docs](http://python-sunlight.rtfd.org/))

## Other

### Migrating from our old Sunlight Congress API

This Sunlight Congress API replaces and deprecates our [old Sunlight Congress API](http://services.sunlightlabs.com/docs/Sunlight_Congress_API/). We will keep the old Congress API running until at least the end of the 113th Congress (January 2015).  We advise users of the old Congress API to upgrade to this one as soon as possible.

We have prepared a [migration guide](migration.html) that shows how to move from each method in the old API to the new API.

### Congress on IFTTT

The Sunlight Foundation has an [IFTTT channel](https://ifttt.com/sunlightfoundation) that offers some "Triggers" based on events in Congress.

Check out our [shared recipes](https://ifttt.com/p/sunlightfoundation) and our [favorite recipes](https://ifttt.com/p/sunlightfoundation#favorites) for some examples of how to make use of our congressional data with IFTTT.

### More APIs

If the Sunlight Congress API doesn't have what you're looking for, check out other Congress APIs:

* [GovTrack Data API](http://www.govtrack.us/developers/api)
* [New York Times Congress API](http://developer.nytimes.com/docs/congress_api)

Or if you're looking for other government data:

* [Open States API](http://openstates.org/api/) - Legislative data for all 50 US states, DC, and Puerto Rico.
* [FederalRegister.gov API](https://www.federalregister.gov/learn/developers) - Official (government-run) JSON API for the activity of the US' executive branch. Includes all proposed and final regulations, executive orders, and all kinds of things.
* [Capitol Words API](http://capitolwords.org/api/) - Search speeches of members of Congress (the Congressional Record), and get all sorts of language analysis on frequently used words and phrases.
* [Influence Explorer API](http://data.influenceexplorer.com/api) - Data around federal lobbying, grants, contracts, and state and federal campaign contributions.
