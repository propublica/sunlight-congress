---
layout: default
---


* placeholder
{:toc}

# Votes

Roll call votes taken by the House and Senate. This data is taken from original [House](http://clerk.house.gov/legislative/legvotes.aspx) and [Senate](http://www.senate.gov/pagelayout/legislative/a_three_sections_with_teasers/votes.htm) sources, and goes back to 2009.

House and Senate votes normally appear within an hour after the vote is taken. House data usually appears more quickly, since the House uses an electronic voting system.

Votes taken by voice or unanimous consent, where the votes of individual representatives and senators are not recorded, are not present here.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

### /votes

Search and filter through votes in Congress. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Recent votes in the Senate**

{% highlight text %}
/votes?chamber=senate&order=voted_at
{% endhighlight %}

**Votes about 'guns'**

{% highlight text %}
/votes?query=guns
{% endhighlight %}

**Votes taken by Rep. Robert Aderholt**

{% highlight text %}
/votes?voter_ids.A000055__exists=true
{% endhighlight %}

**Votes since July 2, 2013**

{% highlight text %}
/votes?voted_at__gte=2013-07-02T4:00:00Z
{% endhighlight %}

## Fields

**Many fields are not returned unless requested.** You can request specific fields with the `fields` parameter. See the [partial responses](index.html#parameters/partial-responses) documentation for more details.

\* = can be used as a filter

{% highlight json %}
{
  "roll_id": "h7-2013",
  "chamber": "house",
  "number": 7,
  "year": 2013,
  "congress": 113,
  "voted_at": "2013-01-04T16:22:00Z",
  "vote_type": "passage",
  "roll_type": "On Motion to Suspend the Rules and Pass",
  "question": "On Motion to Suspend the Rules and Pass -- H.R. 41 -- To temporarily increase the borrowing authority of the Federal Emergency Management Agency for carrying out the National Flood Insurance Program",
  "required": "2/3",
  "result": "Passed",
  "source": "http://clerk.house.gov/evs/2013/roll007.xml"
}
{% endhighlight %}

\* **roll_id**
A unique identifier for a roll call vote. Made from the first letter of the `chamber`, the vote `number`, and the legislative `year`.

\* **chamber**
The chamber the vote was taken in. "house" or "senate".

\* **number**
The number that vote was assigned. Numbers reset every legislative year.

\* **year**
The "legislative year" of the vote. This is **not quite the same** as the calendar year - the legislative year changes at noon EST on January 3rd. A vote taken on January 1, 2013 has a "legislative year" of 2012.

\* **congress**
The Congress this vote was taken in.

\* **voted_at**
The time the vote was taken.

\* **vote_type**
The type of vote being taken. This classification is imperfect and unofficial, and may change as we improve our detection. Valid types are "passage", "cloture", "nomination", "impeachment", "treaty", "recommit", "quorum", "leadership", and "other".

\* **roll_type**
The official description of the type of vote being taken.

**question**
The official full question that the vote is addressing.

\* **required**
The required ratio of Aye votes necessary to pass the legislation. A value of "1/2" actually means more than 1/2. Ties are not possible in the Senate (the Vice President casts a tie-breaker vote), and in the House, a tie vote means the vote does not pass.

\* **result**
The official result of the vote. This is not completely standardized (both "Passed" and "Bill Passed" may appear). In the case of a vote for Speaker of the House, the `result` field contains the name of the victor.

**source**
The original, official source XML for this vote information.

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
If a vote is related to a [bill](bills.html), the bill's ID.

**bill**
If a vote is related to a [bill](bills.html), some basic fields about the bill.

### Associated Nominations

{% highlight json %}
{
  "nomination_id": "PN202-113",
  "nomination": {
    "organization": "The Judiciary",
    "received_on": "2013-03-19",
    "nominees": [
      {
        "name": "Elaine D. Kaplan",
        "position": "Judge of the United States Court of Federal Claims",
        "state": "DC"
      }
    ]
    ...
  }
}
{% endhighlight %}

These fields can only occur on Senate votes, as the Senate is the only chamber which considers presidential nominations.

\* **nomination_id**
If a vote is related to a [nomination](nominations.html), the nomination's ID.

**nomination**
If a vote is related to a [nomination](nominations.html), some basic fields about the nomination.

### Voters

{% highlight json %}
{
  "voter_ids": {
    "A000055": "Yea",
    "A000361": "Yea"
    ...
  },
  "voters": {
    "A000055": {
      "vote": "Yea",
      "voter": {
        "bioguide_id": "A000055",
        "chamber": "house"
        ...
      }
    },
    "A000361": {
      "vote": "Yea",
      "voter": {
        "bioguide_id": "A000361",
        "chamber": "house"
        ...
      }
    }
    ...
  }
}
{% endhighlight %}

Most votes are "Yea", "Nay", "Present", and "Not Voting". There are exceptions: in the Senate, impeachment votes are "Guilty" or "Not Guilty". In the House, votes for the Speaker of the House are the name of the person being voted for (e.g. "Pelosi" or "Boehner"). There may be other exceptions.

**voter_ids**
An object connecting bioguide IDs of [legislators](legislators.html) to the vote values they cast.

**voters**
An object connecting bioguide IDs to their vote value, and some basic information about the voter.

**voters.vote**
The value of the vote this voter cast.

**voters.voter**
Some basic fields about the voter.

### Vote Breakdown

{% highlight json %}
{
  "breakdown": {
    "total": {
      "Yea": 62,
      "Nay": 36,
      "Not Voting": 2,
      "Present": 0
    },
    "party": {
      "R": {
        "Yea": 9,
        "Nay": 36,
        "Not Voting": 0,
        "Present": 0
      },
      "D": {
        "Yea": 52,
        "Not Voting": 1,
        "Nay": 0,
        "Present": 0
      },
      "I": {
        "Not Voting": 1,
        "Yea": 1,
        "Nay": 0,
        "Present": 0
      }
    }
  }
}
{% endhighlight %}

The vote **breakdown** gives top-level numbers about what votes were cast.

Most votes are "Yea", "Nay", "Present", and "Not Voting". There are exceptions: in the Senate, impeachment votes are "Guilty" or "Not Guilty". In the House, votes for the Speaker of the House are the name of the person being voted for (e.g. "Pelosi" or "Boehner"). There may be other exceptions.

Values for "Present" and "Not Voting" will always be present, no matter what kind of vote it is.

These fields are dynamic, but can all be filtered on.

\* **breakdown.total.[vote]**
The number of members who cast [vote], where [vote] is a valid vote as defined above.

\* **breakdown.party.[party].[vote]**
The number of members of [party] who cast [vote], where [party] is one of "D", "R", or "I", and [vote] is a valid vote as defined above.

### RSS

If [experimental RSS support](/#rss-support-experimental) is enabled, the following field->RSS mapping will be used by default:

RSS field | Result field
|:--------------|-------------------|
`<title>` | `question`
`<description>` | `result`
`<link>` | `url`
`<guid>` | `roll_id`
`<pubDate>` | `voted_at`