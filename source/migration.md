# Migrating

This Congress API deprecates our previous [Congress API](http://services.sunlightlabs.com/docs/Sunlight_Congress_API/). The new Congress API keeps nearly all the data and features the old one offered.

We will keep our previous Congress API running until the end of the 113th Congress. Users are advised to upgrade to our new Congress API as soon as possible.

This guide shows how to move from each method in the old API to the new API.

## General

### New URL

The previous API root was `http://services.sunlightlabs.com/api/`. The new API root is:

```text
http://congress.api.sunlightfoundation.com
```

Both the previous API and the new API require your [Sunlight API key](http://services.sunlightlabs.com/accounts/register/), so an API method documented as `/legislators/locate` would be used as:

```text
http://congress.api.sunlightfoundation.com/legislators/locate?apikey=[your_api_key]
```

### JSON only

We no longer support XML responses in our Congress API. All responses are in JSON.

### JSONP parameter change

We still support [JSONP](http://en.wikipedia.org/wiki/JSONP), but the parameter has been changed from `jsonp` to `callback`. See the [JSONP documentation](index.html#parameters/jsonp) for more details.

### Response structure

All responses in the new Congress API are in the following form:

```json
{
  "results": [
    ... result objects ...
  ],
  "count": 123,
  "page": {
    "count": 20,
    "per_page": 20,
    "page": 1
  }
}
```

All endpoints are plural, and return an array of objects. To look up a single object, use search criteria that guarantee a single result and look for the first (and only) result.

The `count` and `page` fields are always present, explained in [Pagination](index.html#parameters/pagination). The only exceptions are requests to `/districts/locate`, which does not use pagination.

### Requesting fields

By default, not all fields are returned for most objects in the new Congress API. 

For example, a legislator's `terms` field, which contains extensive data on that member's past terms, does not appear for a plain request to `/legislators`.

Fields can be requested using the `fields` parameter:

```text
/legislators?fields=bioguide_id,last_name,state,terms
```

This is documented further in [Partial Responses](index.html#parameters/partial-responses).

## Legislators

### Field changes

The following fields have been renamed:

* `firstname` -> `first_name`
* `middlename` -> `middle_name`
* `lastname` -> `last_name`
* `webform` -> `contact_form`
* `congress_office` -> `office`
* `birthdate` -> `birthday`
* `youtube_url` -> `youtube_id`

The following fields have been dropped altogether:

* `congresspedia_url`
* `official_rss`
* `email`
* `eventful_id`

The following fields have changed:

* `fec_id` is now an array of strings, instead of a string.
* `senate_class` is now a number (1, 2, 3), instead of a string ("I", "II", "III") .
* `district` no longer contains "Senior Seat" or "Junior Seat" for Senators - it will be `null`. Instead, the `state_rank` field will say "Junior" or "Senior".
* `youtube_id` is now just the member's username on YouTube, instead of the full URL.

The following fields are new:

* `state_rank` - "junior" or "senior", for Senators
* `state_name` - Full state name (e.g. "Pennsylvania")
* `lis_id` - An official ID used by some sources for Senators.
* `thomas_id` - An official ID used by THOMAS.gov and Congress.gov for members present in those systems.
* `term_start` - The start date of the member's current term.
* `term_end` - The end date of the member's current term.
* `terms` - An array of objects with data for each term. 

See the [documentation for legislators](legislators.html) for more information.


### legislators.getList

In general, finding legislators is very similar.

**Filtering on fields**

When filtering on a chamber, use the `chamber` field instead of `title`.

```text
# old API:
/legislators.getList.json?title=Sen&state=MT&lastname=Tester

# new API:
/legislators?chamber=senate&state=MT&last_name=Tester
```

**Multiple values for a parameter**

Instead of repeating a parameter, use the "in" operator with a pipe-separated list of values:

```text
# old API:
/legislators.getList?lastname=Obama&lastname=McCain

# new API:
/legislators?last_name__in=Obama|McCain
```

The [Operators](index.html#parameters/operators) documentation has more details on operators and filtering.

### legislators.get

Finding a single legislator is the same as finding many. Filter by criteria that uniquely identify a legislator, and use the first (and only) result.

```text
# old API:
/legislators.get?bioguide_id=L000551

# new API:
/legislators?bioguide_id=L000551
```

### legislators.allForLatLong

Use the `/legislators/locate` endpoint.

```text
# old API:
/legislators.allForLatLong.json?latitude=47.603560&longitude=-122.329439

# new API:
/legislators/locate?latitude=47.603560&longitude=-122.329439
```

### legislators.allForZip

Use the `/legislators/locate` endpoint. 

```text
# old API:
/legislators.allForZip.json?zip=11216

# new API:
/legislators/locate?zip=11216
```

### legislators.search

You can use the `query` parameter to match a text fragment against any of legislators' name fields.

We **no longer support** "fuzzy search" of legislator names. The given `query` must match or be contained in one of the fields exactly.

**Any legislators whose name somehow matches "smi"**

```text
# old API:
/legislators.search?name=smi

# new API:
/legislators?query=smi
```

## Districts

[Districts](districts.html) can still only be found by location. The `/districts/locate` endpoint does not return pagination information. The fields remain the same: `state` and `district`, where an "At-Large" district is coded as `0`.

### districts.allForLatLong

```text
# old API:
/districts.allForLatLong.json?latitude=47.603560&longitude=-122.329439

# new API:
/districts/locate?latitude=47.603560&longitude=-122.329439
```

### districts.allForZip

```text
# old API:
/districts.allForZip.json?zip=11216

# new API:
/districts/locate?zip=11216
```

## Committees

[Committees](committees.html) and subcommittees are now mixed together. Finding all committees a legislator is assigned to no longer requires its own endpoint.

IDs have changed for a few committees, and for all subcommittees - they are now sourced entirely from official resources.

We have added contact information for committees, and title information for membership (e.g. "Chair", "Ranking Member", etc.)

### Field changes

The following fields have been renamed:

* `id` -> `committee_id`

The following fields have changed:

* `chamber` - Now lowercase ("senate", "house", "joint").
* `name` - Subcommittees are no longer prefixed with "Subcommittee on".
* `members` - The structure has changed to include the `side`, `rank`, and `title` of committee members.
* `subcommittees` - The structure has changed, and additional fields are included.

The following fields are new:

* `url` - The official website for this committee.
* `office` - The building and room number of this committee.
* `phone` - The official phone number for the committee.
* `member_ids` - An array of bioguide IDs of members of the committee. Useful for filtering.
* `subcommittee` - A boolean, whether or not the committee is a subcommittee.
* `parent_committee_id` - If the committee is a subcommittee, the ID of its parent committee.
* `parent_committee` - If the committee is a subcommittee, some fields about its parent committee.

See the full [Committees](committees.html) documentation for more information.

### committees.getList

In general, finding committees is very similar.

**Filtering on fields**

```text
# old API:
/committees.getList?chamber=House

# new API:
/committees?chamber=house
```

### committees.get

Finding a single committee is the same as finding many. Filter by criteria that uniquely identify a committee, and use the first (and only) result.

```text
# old API:
/committees.get?id=HSSM

# new API:
/committees?committee_id=HSSM
```

### committees.allForLegislator

Use the `/committees` endpoint with a filter on `member_ids` to limit the response to committees and subcommittees the legislator servers on.

```text
# old API:
/committees.allForLegislator?bioguide_id=S000148

# new API:
/committees?member_ids=S000148
```