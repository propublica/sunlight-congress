---
layout: default
---


* placeholder
{:toc}

# Hearings

Committee hearings scheduled by the House and Senate. This data is taken from original [House](http://house.gov/legislative/) and [Senate](http://www.senate.gov/pagelayout/committees/b_three_sections_with_teasers/committee_hearings.htm) sources.

This endpoint is future-looking. We don't automatically delete data on past hearings, but we also don't guarantee non-recent data will remain available.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

### /hearings

Search and filter through committee hearings in the House and Senate. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**House committee hearings in DC**

{% highlight text %}
/hearings?chamber=house&dc=true
{% endhighlight %}

**Hearings about 'children'**

{% highlight text %}
/hearings?query=children
{% endhighlight %}

This will search hearings' `description` field.

## Fields

\* = can be used as a filter

{% highlight json %}
{
  "committee_id": "HSIF",
  "occurs_at": "2013-01-22T15:00:00Z",
  "congress": 113,
  "chamber": "house",

  "dc": true,
  "room": "2123 Rayburn HOB",
  "description": "Hearings to examine the state of the right to vote after the 2012 election.",

  "bill_ids": [],

  "url": "http://energycommerce.house.gov/markup/committee-organizational-meeting-113th-congress",
  "hearing_type": "Hearing"
}
{% endhighlight %}

\* **committee_id**
The ID of the [committee](committees.html) holding the hearing.

\* **occurs_at**
The time the hearing will occur.

\* **congress**
The number of the Congress the committee hearing is taking place during.

\* **chamber**
The chamber of the committee holding the hearing. "house", "senate", or "joint".

\* **dc**
Whether the committee hearing is held in DC (true) or in the field (false).

**room**
If the hearing is in DC, the building and room number the hearing is in. If the hearing is in the field, the address of the hearing.

**description**
A description of the hearing.

\* **bill_ids**
The IDs of any [bills](bills.html) mentioned by or associated with the hearing.

**url**
(House only) A permalink to that hearing's description on that committee's official website.

\* **hearing_type**
(House only) The type of hearing this is. Can be: "Hearing", "Markup", "Business Meeting", "Field Hearing".

### Committee Details

{% highlight json %}
{
  "committee": {
    "address": "2125 RHOB; Washington, DC 20515",
    "chamber": "house",
    "committee_id": "HSIF",
    "name": "House Committee on Energy and Commerce",
    "office": "2125 RHOB",
    "phone": "(202) 225-2927",
    "subcommittee" :false
  }
}
{% endhighlight %}

Basic details about the related [committee](committees.html) will appear in the **committee** field.