The Real Time Congress (RTC) API is a RESTful API over the artifacts of Congress, in as close to real-time as possible. There is no original data; all data is taken automatically from other sources.

RTC is essentially a very thin layer over [MongoDB](http://www.mongodb.org/). If you are familiar with MongoDB's philosophy and search operators, you will be very comfortable with the Real Time Congress API. If you're not, you'll find it's very simple to learn.

This API is not a source of archival data. RTC will have up to date for the current Congress, and archival information for the previous Congress, but that's it. For archives of Congressional information, use [GovTrack.us](http://govtrack.us) or the [NYT Congress API](http://developer.nytimes.com/docs/congress_api).

### Getting Started

* [Register for a Sunlight Services API Key](/accounts/register/)
* Read these docs, or play around with URLs
* Ask questions/show off your project on the [Sunlight API Google Group](http://groups.google.com/group/sunlightlabs-api-
discuss)

### URL structure

http://api.realtimecongress.org/api/v1/[collection].[json|xml]

Examples of a value for collection would be "bills", "floor_updates", "videos", etc.

You must pass in a Sunlight Labs API key in order to use the service. This can be provided in the query string, using the format "apikey=[yourApiKey]", or as an HTTP request header named "X-APIKEY".

This is version 1 of the API. New data and methods may be added to it without notification, but no data will be removed, and no backwards-incompatible changes will be made without seeking community input, or advancing to a version 2.

### Collections

There are 7 collections in the Real Time Congress API. Select any of them to see a definition of each field. 

* [bills](http://services.sunlightlabs.com/docs/Real_Time_Congress_API/bills/)
* [votes](http://services.sunlightlabs.com/docs/Real_Time_Congress_API/votes/)
* [amendments](http://services.sunlightlabs.com/docs/Real_Time_Congress_API/amendments/)
* [videos](http://services.sunlightlabs.com/docs/Real_Time_Congress_API/videos/)
* [floor_updates](http://services.sunlightlabs.com/docs/Real_Time_Congress_API/floor_updates/)
* [committee_hearings](http://services.sunlightlabs.com/docs/Real_Time_Congress_API/committee_hearings/)
* [documents](http://services.sunlightlabs.com/docs/Real_Time_Congress_API/documents/)

### Responses

Every call to the API returns a list of documents, filtered on various criteria. If you are searching for a single document, filter the collection on something unique to receive an array of one item.

#### Pagination

To control pagination, use "page" and "per_page" parameters to specify how many results you want, and where to start from.  The default number of documents per page is 20, and can be set to a maximum of 500.

#### Metadata

In addition to the requested documents, each response includes a "count" field, and a "page" object with its own fields.

<script src="https://gist.github.com/773822.js?file=pagination.json"></script>

* **count** - Total number of documents in the collection which matched the parameters, ignoring pagination. Can be more than the number of results returned.
* **page.count** - The number of results returned. This will be less than or equal to the **page.per_page** field.
* **page.per_page** - The actual per_page value used for the query. For example, if the "per_page" parameter passed on the query string was above the maximum of 500, this field will be 500.
* **page.page** - The actual page number used for the query. For example, if the "page" parameter passed on the query string was invalid (like -1), this field will be 1.

### Filtering

To filter results, pass the field to filter, and the value to filter it on, on the query string. You can supply multiple filters.

Results containing only H.R. 3590 from the 111th Congress: 

    /api/v1/bills.json?apikey=[yourKey]&bill_id=hr3590-111

All bills enacted into law during the 111th Congress: 

    /api/v1/bills.json?apikey=[yourKey]&enacted=true&session=111


**Note**: The API will try to automatically infer the type of values you supply. A value of "true" or "false" will be treated as a boolean, and any value with all digits will be treated as an integer.

You can also use various operators to perform more powerful queries, by appending "__[operator]" to the end of the field name you are filtering on.

Supported operators, all used by appending "__[operator]" to the end of a field name, are:

* **lt** - Less than
* **lte** - Less than or equal to
* **gt** - Greater than
* **gte** - Greater than or equal to
* **ne** - Not equal to
* **match** - Interprets the value as a case-insensitive regular expression
* **match_s** - Interprets the value as a case-sensitive regular expression
* **exists** - Checks whether the field exists at all
* **in** - Checks whether the field is within the given set of values
* **nin** - Checks whether the field is not within the given set of values
* **all** - Checks whether the field contains every item in the given set of values

Operators which use filter on a list of values (nin, in, and all) require their values to be separated by pipes ("|").

For example, to see all roll call votes on passage of bills in the 111th Congress that went onto become law, that got no more than 1 Republican vote:

    /api/v1/votes.json?apikey=sunlight9&how=roll&vote_type=passage&bill.enacted=true&party_vote_breakdown.party.R.Yea__lte=1

Or all bills in the 111th Congress which got at least one passage vote, but never became law

    /api/v1/bills.json?apikey=[yourKey]&session=111&bill_type__in=h|s|hjres|sjres&passage_votes_count__gte=1&enacted=false

### Ordering

The following query string parameters govern sorting:

* **order** - Supply the field name to sort on. If not provided, each model has a field it orders on by default.
* **sort** - Must be either "asc" or "desc".

Sorting on multiple fields is not supported.

### Partial Responses

Use the "sections" parameter to retrieve a subset of fields from each document in the list. Provide a comma-separated list of fields to retrieve only those fields. Use dot notation to specify fields in subobjects.

    /api/v1/votes.json?apikey=[yourKey]&sections=question,vote_breakdown

You can also use the special "basic" section to get the most central, common fields for a given document. This can be combined with other fields.

    /api/v1/bills.json?apikey=[yourKey]&sections=basic,voters.L000551

### Full text search

The API provides a naive (not native) full text search feature. By passing a "search" key on the query string, it will perform an "or" query, using the given value as a case-insensitive regular expression, over a predefined set of fields. The fields that are searched are different for each collection.

For example, on the bills collection, this will search through the three title fields, the summary, and the keywords array for the pattern "health care":

    /api/v1/bills.json?apikey=[yourKey]&search=health%20care

This is meant to be a general relevance search, something that you can feed user input directly into and return the "best" search results, without worrying much about the details. 

We may change what fields get searched over time, or the entire backend implementation. The syntax for searching, however, will remain the same.

### Explaining queries

To see what actually happens for a particular API call, add "explain=true" to the query string to get a breakdown of what query parameters got sent to the database, and the database's strategy for executing the query.

This returns several fields:

* **conditions** - The hash of conditions, as it was passed into MongoDB.
* **fields** - An array of fields requested. If this is null, it means that all fields will be returned.
* **order** - A two-element array of the sorting field, and the sorting direction.
* **explain** - The hash of explain details as returned by MongoDB's native explain feature.

An explanation of what happens when you search for all passed amendments:

    /api/v1/amendments.json?apikey=[yourKey]&state=pass&explain=true

See the official [MongoDB documentation](http://www.mongodb.org/display/DOCS/Optimization#Optimization-Explain) for more detail about the contents of the "explain" field.

### JSONP

Pass a "callback" parameter to trigger a JSONP response, wrapped in the callback you provide.

<script src="https://gist.github.com/773822.js?file=jsonp.js"></script>

Because every API call returns a list of search results, there are no 404s in the Real Time Congress API, unless you specify an invalid collection name. So, your JSONP request should always get its callback executed in your browser.

If you want to make sure the browser doesn't cache the results of a particular query, you can attach a timestamp to a lone underscore parameter (e.g. "_=1234567890"), which will be ignored by the API. This is what jQuery does by default.

### XML

Though all the examples here are in JSON, you can get the same results in XML by using ".xml" instead of ".json" in the URL.

Additionally, the "explain" feature can be used with XML, but the dollar signs in keys will make it technically invalid XML.

### "Or" queries

"Or" queries are not supported at this time. All filters applied are "and" queries. 

The exception is full text searching, which applies an "or" query across a predefined set of fields on a document.

### Database fields

Each document is stripped of three fields before being returned in the response: 

* **_id** - The MongoDB native database ID.
* **created_at** - The date the entry was added to the database.
* **updated_at** - The date the entry was last updated in the database.

They don't have anything to do with the actual data in the API, but if you want the fields for some reason, you can explicitly ask for them in the "sections" parameter and they will be returned.

<script src="https://gist.github.com/773822.js?file=database_fields.json"></script>
