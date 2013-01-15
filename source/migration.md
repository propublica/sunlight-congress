# Migrating

This Congress API deprecates our previous [Congress API](http://services.sunlightlabs.com/docs/Sunlight_Congress_API/). The new Congress API keeps nearly all the data and features the old one offered. 

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

### Response structure

All responses in the new Congress API are in the following form:

```json
{
  "results": [
    ... result objects ...
  ],
  "count": 123,
  "page": {
    "count": 1,
    "per_page": 20,
    "page": 1
  }
}
```

All endpoints are plural, and return an array of objects. To look up a single object, use search criteria that guarantee a single result and look for the first (and only) result.

The `count` and `page` fields are always present, explained in [Pagination](index.html#parameters/pagination). The only exceptions are requests to `/districts/locate`, which do not use pagination. 

## Legislators

### Field changes

The following fields have been renamed:

The following fields have been dropped altogether:

* opencongress_

### legislators.getList and legislators.get

### legislators.allForZip and legislators.allForLatLong

### legislators.search

## Districts

### districts.allForZip and districts.allForLatLong

## Committees

### Field changes

### committees.getList

### committees.get

### committees.allForLegislator

