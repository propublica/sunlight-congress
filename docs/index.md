# Sunlight Congress API

A live JSON API for the people and work of Congress.

## Features

The Sunlight Congress API has lots of features around members of Congress:

* Look up legislators by location (lat/lng) or by zip code.
* Crosswalk for IDs of legislatrs across various official and 3rd party services.
* Official Twitter, YouTube, and Facebook accounts for legislators.
* Committees and subcommittees in Congress, including memberships and rankings.

We also provide Congress' daily work:

* All introduced bills in the House and Senate, and what occurs to them (updated daily).
* Full text search over bills, with powerful Lucene-based query syntax.
* Real time notice of votes, floor activity, and committee hearings, and when bills are scheduled for debate.

All data is served in JSON, and requires a Sunlight API key. An API key is [free to register](http://services.sunlightlabs.com/accounts/register/) and has no usage limits.


## Getting Started

The Sunlight Congress API lives at:

    http://congress.api.sunlightfoundation.com

There are three types of methods in the Congress API:

**Filter** methods return paginated lists of documents, that can be sorted and filtered by various fields and operators. These methods support partial responses, meaning you can ask just for specific fields. Some large fields must be specifically asked for. Under the hood, these methods use [MongoDB](http://www.mongodb.org/).

**Search** methods can execute a full-text search query, using a Lucene-based query string syntax. Search methods can also do everything that filter methods do - sorting, pagination, filtering, operators, and partial responses. Under the hood, these methods use [ElasticSearch](http://www.elasticsearch.org/).

**Locate** methods look up data by `latitude` and `longitude`, or by a `zip` code. No sorting, pagination, or other filters. Under the hood, this uses a [modified version](https://github.com/sunlightlabs/pentagon) of the Chicago Tribune's [Boundary Service](https://github.com/newsapps/django-boundaryservice).

All methods are plural, and return arrays of documents. To fetch a single document, filter by that document's unique ID, and look at the first (only) document in the result set.


# Methods

There are endpoints that filter:

* /legislators
* /committees
* /bills
* /votes
* /floor_updates
* /hearings
* /upcoming_bills



* /legislators/locate
* /districts/locate


## Bulk Data

Core data for legislators, committees, and bills come from public domain [scrapers](https://github.com/unitedstates/congress) and [bulk data](https://github.com/unitedstates/congress-legislators) at [github.com/unitedstates](https://github.com/unitedstates/). 

The Congress API is not designed for bulk data downloads. Requests are limited to a maximum of 50 per page, and many fields need to be specifically requested. Please use the above resources to collect this data.

## Planned Features

* All amendments to bills introduced in the House and Senate.
* Various relevant documents: 
    * GAO reports, CBO reports, CRS reports, statements of Administration Policy.
    * Full text search over these documents.