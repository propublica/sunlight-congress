---
layout: page
title: Committees
---
# Committees

Names, IDs, contact info, and memberships of committees and subcommittees in the House and Senate. 

All committee information is sourced from bulk data at [github.com/unitedstates](https://github.com/unitedstates/congress-legislators), which in turn comes from official [House](http://clerk.house.gov/committee_info/index.aspx) and [Senate](http://www.senate.gov/general/committee_assignments/assignments.htm) sources.

We only provide information on current committees and memberships. For historic data on committee names, IDs, and contact info, refer to the [bulk data](https://github.com/unitedstates/congress-legislators).

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
http://congress.api.sunlightfoundation.com
{% endhighlight %}

### /committees

Filter through committees in the House and Senate. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Committees and subcommittees a given legislator is assigned to**

{% highlight text %}
/committees?member_ids=L000551
{% endhighlight %}

**Joint committees, excluding subcommittees**

{% highlight text %}
/committees?chamber=joint&subcommittee=false
{% endhighlight %}

**Subcommittees of the House Ways and Means Committee**

{% highlight text %}
/committees?parent_committee_id=HSWM
{% endhighlight %}

## Fields

\* = can be used as a filter

{% highlight json %}
{
"name": "House Committee on Homeland Security",
"committee_id":"HSHM",
"chamber":"house",
"url": "http://homeland.house.gov/",
"office": "H2-176 FHOB",
"phone": "(202) 226-8417",
"subcommittee": false,
}
{% endhighlight %}

**name**<br/>
Official name of the committee. Parent committees tend to have a prefix, e.g. "House Committee on", and subcommittees do not, e.g. "Health".
\* **committee_id**<br/>
Official ID of the committee, as it appears in various official sources (Senate, House, and Library of Congress).

\* **chamber**<br/>
The chamber this committee is part of. "house", "senate", or "joint".

**url**<br/>
The committee's official website.

**office**<br/>
The committe's building and room number.

**phone**<br/>
The committee's phone number.

\* **subcommittee**<br/>
Whether or not the committee is a subcommittee.

### Members

{% highlight json %}
{
"member_ids":[
  "K000210",
  "S000583"
  ...
],

"members": [
  {
    "side": "majority",
    "rank": 1,
    "title": "Chair",
    "legislator": {
      "bioguide_id": "K000210",
      "chamber": "house"
      ...
    }
  }
  ...
]
}
{% endhighlight %}
\* **member_ids**<br/>
An array of bioguide IDs of [legislators](legislators.html) that are assigned to this committee.

**members.side**<br/>
Whether a member is in the majority or minority of this committee.

**members.rank**<br/>
The rank this member holds on the committee. Typically, this is calculated by seniority, but there can be exceptions.

**members.title**<br/>
A title, if any, the member holds on the committee. "Chair" (in the House) and "Chairman" (in the Senate) signifies the chair of the committee. "Ranking Member" (in both chambers) signifies the highest ranking minority member.

### Subcommittees

{% highlight json %}
{
"subcommittees": [
  {
    "name": "Cybersecurity, Infrastructure Protection, and Security Technologies",
    "committee_id": "HSHM08",
    "phone": "(202) 226-8417",
    "chamber": "house"
  }
  ...
]
}
{% endhighlight %}

If the committee is a parent committee, the **subcommittees** field contains a few basic fields about its subcommittees.

### Parent Committee

{% highlight json %}
{
"parent_committee_id": "HSSM",
"parent_committee": {
  "committee_id": "HSSM",
  "name": "House Committee on Small Business",
  "chamber": "house",
  "website": null,
  "office": "2361 RHOB",
  "phone":  "(202) 225-5821"
}
}
{% endhighlight %}
\* **parent_committee_id**<br/>
If the committee is a subcommittee, the ID of its parent committee.

**parent_committee**<br/>
If the committee is a subcommittee, some basic details