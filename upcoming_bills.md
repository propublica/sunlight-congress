---
layout: default
---


* placeholder
{:toc}

# Upcoming Bills

Bills that have been scheduled by party leadership for upcoming House and Senate floor action. House schedules are taken from the [House Majority Leader](http://majorityleader.gov/), and Senate schedules from the [Senate Democratic Caucus](http://democrats.senate.gov/).

The endpoint will accrue a running history of scheduled bills. Typically, you will want to ask for the latest upcoming bills, sorted by `scheduled_at` (the time at which we first spotted the bill on the calendar).

Currently, the endpoint defaults to showing only bills in the future and immediate past (7 days ago). If you want different behavior, override the `legislative_day` filter.

**Note:** Prior to March 4, 2014, the endpoint deleted old data on scheduled bills automatically.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

### /upcoming_bills

Filter through upcoming bills in the House and Senate. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

Currently, the endpoint defaults to showing only bills in the future and immediate past (7 days ago). If you want different behavior, override the `legislative_day` filter.

**Latest upcoming bills in the House**

{% highlight text %}
/upcoming_bills?chamber=house&order=scheduled_at
{% endhighlight %}

**Any scheduling of a particular bill**

{% highlight text %}
/upcoming_bills?bill_id=s968-112
{% endhighlight %}

## Fields

\* = can be used as a filter

{% highlight json %}
{
  "bill_id": "sconres3-113",
  "congress": 113,
  "chamber": "senate",
  "source_type": "senate_daily",
  "legislative_day": "2013-01-21",
  "scheduled_at": "2013-01-15T12:24:51Z",
  "range": "day",
  "context": "The Senate stands in recess under the provisions of S.Con.Res.3.  The Senate will meet at 11:30am on Monday, January 21, 2013 for the Joint Session for the Inaugural Ceremonies.",
  "url": "http://democrats.senate.gov/2013/01/21/senate-floor-schedule-for-monday-january-21-2013/"
}
{% endhighlight %}

\* **scheduled_at**
The exact time at which our systems first spotted this bill on the schedule in this chamber and on this legislative day. Currently, we [check the schedules every 15 minutes](https://github.com/sunlightlabs/congress/blob/master/config/cron/production.crontab).

\* **legislative_day**
The legislative day this bill is scheduled for. Combine with the `range` field to understand precision. May be null.

\* **range**
How precise this information is. "day", "week", or null.

* `range` is "day": bill has been scheduled specifically for the `legislative_day`.
* `range` is "week": bill has been scheduled for the "Week of" the `legislative_day`.
* `range` is null: bill has been scheduled at an indefinite time in the future. (`legislative_day` is null.)

The "legislative day" is a formal construct that is usually, but not always, the same as the calendar day. For example, if a day's session of Congress runs past midnight, the legislative_day will often stay the same as it was before midnight, until that session adjourns. On January 3rd, it is possible that the same legislative_day could span two Congresses. (This occurred in 2013.)

\* **congress**
The number of the Congress this bill has been scheduled in.

\* **chamber**
The chamber which has scheduled this bill.

\* **source_type**
The source for this information. "house_daily" ([Majority Leader daily schedule](http://majorityleader.gov/floor/daily.html) or "senate_daily" ([Senate Democrats' Floor feed](http://democrats.senate.gov/floor/).

**context**
(Senate only) Some context for what kind of activity will be occurring to the bill.

**url**
A permalink for this information. For the House, this may be a PDF.

### Associated Bill

{% highlight json %}
{
  "bill_id": "hr41-113",
  "bill": {
    "bill_id": "hr41-113",
    "bill_type": "hr",
    "congress": 113
    ...
  }
}
{% endhighlight %}

\* **bill_id**
The ID of the [bill](bills.html) that is being scheduled.

**bill**
Some basic fields about the [bill](bills.html) that is being scheduled.

### RSS

If [experimental RSS support](/#rss-support-experimental) is enabled, the following field->RSS mapping will be used by default:

RSS field | Result field
|:--------------|-------------------|
`<title>` | `legislative_day`
`<description>` | `bill_id`
`<link>` | `url`
`<guid>` | `url`
`<pubDate>` | `scheduled_at`