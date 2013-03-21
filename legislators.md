---
layout: page
title: Legislators
---
# Legislators

Data on members of Congress, dating back to 1789. All member information is sourced from the bulk data at [github.com/unitedstates](https://github.com/unitedstates/congress-legislators).

**Unique ID**: The **bioguide_id** will be present and unique for all members of Congress. It is an official ID, assigned by Congress, and is the most suitable for use as a unique ID.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
http://congress.api.sunlightfoundation.com
{% endhighlight %}

### /legislators/locate

Find members of Congress by a `latitude` and `longitude`, or a `zip` code. 

There is **no support** for further operators, ordering, or partial responses. All you can do is filter by location.

At-large districts, which encompass an entire state, are assigned a district number of `0`.

**By latitude/longitude**

{% highlight text %}
/legislators/locate?latitude=42.96&longitude=-108.09
{% endhighlight %}

This will return both representatives and senators that currently represent the given point or zip. For a given `latitude` and `longitude`, this should return up to 1 representative and 2 senators. 

**By zip code**

{% highlight text %}
/legislators/locate?zip=11216
{% endhighlight %}

A `zip` code may intersect multiple Congressional districts, so locating by `zip` may return multiple representatives, and possibly more than 2 senators if the zip code crosses state borders.

In general, we [recommend against using zip codes](http://sunlightlabs.com/blog/2012/dont-use-zipcodes/) to look up members of Congress. For one, it's imprecise: a zip code can intersect multiple congressional districts. More importantly, zip codes *are not shapes*. They are lines (delivery routes), and treating them as shapes leads to inaccuracies.

### /legislators

Search and filter for members of Congress. All [standard operators](index.html#parameters/operators) apply.

By default, all requests will return **currently serving members**, but you can override this by supplying `all_legislators=true`.

**Filtering on fields**

{% highlight text %}
/legislators?party=D&chamber=senate
{% endhighlight %}

Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Locating a particular member, whether in office or not**

{% highlight text %}
/legislators?bioguide_id=F000444&all_legislators=true
{% endhighlight %}

**Searching by a string**

{% highlight text %}
/legislators?query=mcconnell
{% endhighlight %}

This will search legislators' name fields: `first_name`, `last_name`, `middle_name`, `nickname`, `other_names.last`

**Disabling pagination**

You can turn off pagination for requests to `/legislators`, but doing so will force a filter of `in_office=true` (that cannot be overridden).

{% highlight text %}
/legislators?per_page=all
{% endhighlight %}


## Fields

\* = can be used as a filter

{% highlight json %}
{
"in_office": true,
"party": "D",
"gender": "M",
"state": "OH",
"state_name": "Ohio",
"district": null,
"title": "Sen",
"chamber": "senate",
"senate_class": 1,
"state_rank": "senior",
"birthday": "1946-12-24",
"term_start": "2007-01-04",
"term_end": "2012-12-31"
}
{% endhighlight %}

\* **in_office**<br/>
Whether a legislator is currently holding elected office in Congress.

\* **party**</br>
First letter of the party this member belongs to. "R", "D", or "I".

\* **gender**<br/>
First letter of this member's gender. "M" or "F".

\* **state**<br/>
Two-letter code of the state this member represents.

\* **state_name**<br/>
The full state name of the state this member represents.

\* **district**<br/>
(House only) The number of the district that a House member represents.

\* **state_rank**<br/>
(Senate only) The seniority of that Senator for that state. "junior" or "senior".

\* **title**<br/>
Title of this member. "Sen", "Rep", "Del", or "Com".

\* **chamber**<br/>
Chamber the member is in. "senate" or "house".

\* **senate_class**</br>
Which senate "class" the member belongs to (1, 2, or 3). Every 2 years, a separate one third of the Senate is elected to a 6-year term. Senators of the same class face election in the same year. Blank for members of the House.

\* **birthday**</br>
The date of this legislator's birthday.

\* **term_start**<br/>
The date a member's current term started.

\* **term_end**<br/>
The date a member's current term will end.

### Identifiers

{% highlight json %}
{
"bioguide_id": "B000944",
"thomas_id": "136",
"govtrack_id": "400050",
"votesmart_id": "27018",
"crp_id": "N00003535",
"lis_id": "S307",
"fec_ids": [
  "H2OH13033"
]
}
{% endhighlight %}

\* **bioguide_id**<br/>
Identifier for this member in various Congressional sources. Originally taken from the [Congressional Biographical Directory](http://bioguide.congress.gov), but used in many places. If you're going to pick one ID as a Congressperson's unique ID, use this.

\* **thomas_id**<br/>
Identifier for this member as it appears on [THOMAS.gov](http://thomas.loc.gov) and [Congress.gov](http://congress.gov).

\* **lis_id**<br/>
Identifier for this member as it appears on some of Congress' data systems (namely [Senate votes](http://www.senate.gov/legislative/LIS/roll_call_votes/vote1122/vote_112_2_00228.xml)).

\* **govtrack_id**<br/>
Identifier for this member as it appears on [GovTrack.us](http://govtrack.us).

\* **votesmart_id**<br/>
Identifier for this member as it appears on [Project Vote Smart](http://votesmart.org/).

\* **crp_id**<br/>
Identifier for this member as it appears on CRP's [OpenSecrets](http://www.opensecrets.org).

\* **fec_ids**<br/>
A list of identifiers for this member as they appear in filings at the [Federal Election Commission](http://fec.gov/).

### Names

{% highlight json %}
{
"first_name": "Jefferson",
"nickname": "Jeff",
"last_name": "Brown",
"middle_name": "B.",
"name_suffix": null
}
{% endhighlight %}

\* **first_name**<br/>
The member's first name. This may or may not be the name they are usually called.

\* **nickname**<br/>
The member's nickname. If present, usually safe to assume this is the name they go by.

\* **last_name**<br/>
The member's last name.

\* **middle_name**<br/>
The member's middle name, if they have one.

\* **name_suffix**<br/>
A name suffix, if the member uses one. For example, "Jr." or "III".

### Contact info

{% highlight json %}
{
"phone": "202-224-2315",
"website": "http://brown.senate.gov/",
"office": "713 Hart Senate Office Building",
"contact_form": "http://www.brown.senate.gov/contact/",
"fax": "202-228-6321"
}
{% endhighlight %}

**phone**<br/>
Phone number of the members's DC office.

**fax**<br/>
Fax number of the members's DC office.

**office**<br/>
Office number for the member's DC office.

**website**<br/>
Official legislative website.

**contact_form**<br/>
URL to their official contact form.

### Social Media

{% highlight json %}
{
"twitter_id": "SenSherrodBrown",
"youtube_id": "SherrodBrownOhio",
"facebook_id": "109453899081640"
}
{% endhighlight %}

**twitter_id**<br/>
The Twitter *username* for a member's official legislative account. This field does not contain the handles of campaign accounts.

**youtube_id**<br/>
The YouTube *username or channel* for a member's official legislative account. This field does not contain the handles of campaign accounts. A few legislators use YouTube "channels" instead of regular accounts. These channels will be of the form `channel/[id]`.

**facebook_id**<br/>
The Facebook *username or ID* for a member's official legislative Facebook presence. ID numbers and usernames can be used interchangeably in Facebook's URLs and APIs. The referenced account may be either a Facebook Page or a user account.

All social media account values can be turned into URLs by preceding them with the domain name of the service in question:

* `http://twitter.com/[username]`
* `http://youtube.com/[username or channel ID]`
* `http://facebook.com/[username or ID]`

### Terms

An array of information for each term the member has served, from oldest to newest. Example:

{% highlight json %}
{
"terms": [{
  "start": "2013-01-03",
  "end": "2019-01-03",
  "state": "NJ",
  "party": "D",
  "class": 1,
  "title": "Sen",
  "chamber": "senate"
}]
}
{% endhighlight %}

**terms.start**<br/>
The date this term began.

**terms.end**<br/>
The date this term ended, or will end.

**terms.state**<br/>
The two-letter state code this member was serving during this term.

**terms.party**<br/>
The party this member belonged to during this term.

**terms.title**<br/>
The title this member had during this term. "Rep", "Sen", "Del", or "Com".

**terms.chamber**<br/>
The chamber this member served in during this term. "house" or "senate".

**terms.class**<br/>
The Senate class this member belonged to during this term, if they served in the Senate. Determines in which cycle they run for re-election. 1, 2, or 3.