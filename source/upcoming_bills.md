# Upcoming Bills

Bills that have been scheduled by party leadership for upcoming House and Senate floor action. House schedules are taken from the [House Majority Leader](http://majorityleader.gov/), and Senate schedules from the [Senate Democratic Caucus](http://democrats.senate.gov/).

This endpoint is future-looking only. Old data on bills scheduled in the past is automatically deleted.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

```text
http://congress.api.sunlightfoundation.com
```

### /upcoming_bills

Filter through upcoming bills in the House and Senate. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Upcoming bills in the House**

```text
/upcoming_bills?chamber=house
```

**Any scheduling of a particular bill**

```text
/upcoming_bills?bill_id=s968-112
```

## Fields

\* = can be used as a filter

```json
{
"bill_id": "sconres3-113",
"congress": 113,
"chamber": "senate",
"source_type": "senate_daily",
"legislative_day": "2013-01-21",
"range": "day",
"context": "The Senate stands in recess under the provisions of S.Con.Res.3.  The Senate will meet at 11:30am on Monday, January 21, 2013 for the Joint Session for the Inaugural Ceremonies.",
"url": "http://democrats.senate.gov/2013/01/21/senate-floor-schedule-for-monday-january-21-2013/"
}
```

\* **legislative_day**<br/>
The legislative day this bill is scheduled for. Combine with the `range` field to understand precision. May be null.

\* **range**<br/>
How precise this information is. "day", "week", or null. 

* `range` is "day": bill has been scheduled specifically for the `legislative_day`.
* `range` is "week": bill has been scheduled for the "Week of" the `legislative_day`. 
* `range` is null: bill has been scheduled at an indefinite time in the future. (`legislative_day` is null.)

The "legislative day" is a formal construct that is usually, but not always, the same as the calendar day. For example, if a day's session of Congress runs past midnight, the legislative_day will often stay the same as it was before midnight, until that session adjourns. On January 3rd, it is possible that the same legislative_day could span two Congresses. (This occurred in 2013.)

\* **congress**<br/>
The number of the Congress this bill has been scheduled in.

\* **chamber**<br/>
The chamber which has scheduled this bill.

\* **source_type**<br/>
The source for this information. "house_daily" ([Majority Leader daily schedule](http://majorityleader.gov/floor/daily.html) or "senate_daily" ([Senate Democrats' Floor feed](http://democrats.senate.gov/floor/).

**context**<br/>
(Senate only) Some context for what kind of activity will be occurring to the bill.

**url**<br/>
A permalink for this information. For the House, this may be a PDF.

### Associated Bill

```json
{
"bill_id": "hr41-113",
"bill": {
  "bill_id": "hr41-113",
  "bill_type": "hr",
  "congress": 113
  ...
}
}
```

\* **bill_id**<br/>
The ID of the [bill](bills.html) that is being scheduled.

**bill**<br/>
Some basic fields about the [bill](bills.html) that is being scheduled.