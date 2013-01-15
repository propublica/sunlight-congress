# Districts

Find a congressional district for a given coordinate, or for a zip code. Congressional districts are calculated based on data from the [2010 Census](http://www.census.gov/rdo/data/).

For zip code lookup, we use [ZIP Code Tabulation Areas](http://www.census.gov/geo/reference/zctas.html) (ZCTAs), also published by the Census.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

```text
http://congress.api.sunlightfoundation.com
```

### /districts/locate

Find congressional districts by a `latitude` and `longitude`, or a `zip` code. There is no support for pagination, operators, ordering, or partial responses.

At-large districts, which encompass an entire state, are assigned a district number of `0`.

**By latitude/longitude**

```text
/districts/locate?latitude=42.96&longitude=-108.09
```

For a given `latitude` and `longitude`, this should return 1 congressional district.

**By zip code**

```text
/districts/locate?zip=11216
```

A `zip` code may intersect multiple Congressional districts, so it is not as precise as using a `latitude` and `longitude`.

In general, we [recommend against using zip codes](http://sunlightlabs.com/blog/2012/dont-use-zipcodes/) to look up members of Congress. For one, it's imprecise: a zip code can intersect multiple congressional districts. More importantly, zip codes *are not shapes*. They are lines (delivery routes), and treating them as shapes leads to inaccuracies.

## Fields

```json
{
"state": "NY",
"district": 8
}
```

**state**<br/>
The two-letter state code of the state this district is in.

**district**<br/>
The number of the congressional district. For "At Large" districts, where a state has only one representative, the district number is `0`.