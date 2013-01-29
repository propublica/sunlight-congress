# Floor Updates

Recent real time, to-the-minute updates from the House and Senate floor. House floor updates are sourced from XML at the [House Clerk](http://clerk.house.gov/floorsummary/floor.aspx), and Senate updates from the [Senate Periodical Press Gallery](http://www.senate.gov/galleries/pdcl/index.htm).

This endpoint focuses on the recent past. We don't automatically delete old floor updates, but we also don't guarantee non-recent data will remain available.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

```text
http://congress.api.sunlightfoundation.com
```

### /floor_updates

Search and filter through floor updates in the House and Senate. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Senate floor updates in the 113th Congress**

```text
/floor_updates?chamber=senate&congress=113
```

**Floor activity on a given bill**

```text
/floor_updates?bill_ids=s968-112
```

**House voice votes**

```text
/floor_updates?chamber=house&query=Agreed to by voice vote
```

The value of the `query` parameter will be matched against floor updates' `update` field.

## Fields

\* = can be used as a filter

```json
{
"chamber": "house",
"timestamp": "2013-01-04T18:34:14Z",
"congress": 113,
"year": 2013,
"legislative_day": "2013-01-04",
"update": "The House adjourned pursuant to S. Con. Res. 3. The next meeting is scheduled for 2:00 p.m. on January 14, 2013.",
"bill_ids": [
  "sconres3-113"
],
"roll_ids": [],
"legislator_ids": []
}
```

\* **chamber**<br/>
The chamber this update took place in. "house" or "senate".

\* **timestamp**<br/>
The time this update took place. For Senate updates, this actually means the time our system first observed the update, and is susceptible to error; the Senate does not offer precise timestamps.

\* **congress**<br/>
The number of the Congress this update took place during.

\* **legislative_day**<br/>
The "legislative day" this update took place in. The "legislative day" is a formal construct that is usually, but not always, the same as the calendar day. For example, if a day's session of Congress runs past midnight, the legislative_day will often stay the same as it was before midnight, until that session adjourns. On January 3rd, it is possible that the same legislative_day could span two Congresses. (This occurred in 2013.)

\* **year**<br/>
The "legislative year" of the update. This is **not quite the same** as the calendar year - the legislative year changes at noon EST on January 3rd. A vote taken on January 1, 2013 has a "legislative year" of 2012.

**update**<br/>
The text of the update.

\* **bill_ids**<br/>
An array of IDs of [bills](bills.html) that are referenced by or associated with this floor update.

\* **roll_ids**<br/>
An array of IDs of [roll call votes](votes.html) that are referenced by or associated with this floor update.

\* **legislator_ids**<br/>
An array of bioguide IDs of [legislators](legislators.html) that are referenced by this floor update.