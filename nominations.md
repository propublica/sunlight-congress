---
layout: default
---


* placeholder
{:toc}

# Nominations

Nominations made by the President and referred to the Senate for consideration. This data is taken from [THOMAS.gov's nominations directory](http://thomas.loc.gov/home/nomis.html), and goes back to 2009.

Data is collected using the [unitedstates/congress](https://github.com/unitedstates/congress) project. Feel free to [open a ticket](https://github.com/sunlightlabs/congress/issues/new) with any bugs or suggestions.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

### /nominations

Search and filter through presidential nominations in Congress. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Recent nominations**

{% highlight text %}
/nominations?order=received_on
{% endhighlight %}

**Nominations before the Senate Armed Services Committee**

{% highlight text %}
/nominations?committee_ids=SSAS
{% endhighlight %}

**Nominees to the Privacy and Civil Liberties Oversight Board**

{% highlight text %}
/nominations?organization=Privacy and Civil Liberties Oversight Board
{% endhighlight %}

**Nominees named 'Petraeus'**

{% highlight text %}
/nominations?query=Petraeus
{% endhighlight %}

## Fields

**Many fields are not returned unless requested.** You can request specific fields with the `fields` parameter. See the [partial responses](index.html#parameters/partial-responses) documentation for more details.

\* = can be used as a filter

{% highlight json %}
{
  "nomination_id": "PN1873-111",
  "congress": 111,
  "number": "PN1873",
  "received_on": "2010-06-24",
  "last_action_at": "2010-06-30",
  "organization": "Army",
  "nominees": [
    {
      "name": "Gen. David H. Petraeus",
      "position": "General",
      "state": "PA"
    }
  ],
  "committee_ids": [
    "SSAS"
  ]
}
{% endhighlight %}

\* **nomination_id**
The unique identifier for this nomination, taken from the Library of Congress. Of the form "PN[number]-[congress]".

\* **congress**
The Congress in which this nomination was presented.

\* **number**
The number of this nomination, taken from the Library of Congress. Can occasionally contain hyphens, e.g. "PN64-01".

\* **received_on**
The date this nomination was received in the Senate.

\* **last_action_at**
The date this nomination last received action. If there are no official `actions`, then this field will fall back to the value of `received_on`.

\* **organization**
The organization the nominee would be appointed to, if confirmed.

\* **committee_ids**
An array of IDs of [committees](committees.html) that the nomination has been referred to for consideration.

\* **nominees**
An array of objects with fields (described below) about each nominee. Nominations for civil posts tend to have only one nominee. Nominations for military posts tend to have batches of multiple nominees. In either case, the `nominees` field will always be an array.

**nominees.name**
The name of the nominee, as it appears in THOMAS. Capitalization is not consistent.

\* **nominees.position**
The position the nominee is being nominated for.

\* **nominees.state**
The which state in the United States this nominee hails from. This field is only available for some nominees, and never for batches of multiple nominees.


## Action history

{% highlight json %}
{
  "actions": [
    {
      "acted_at": "2010-06-30",
      "location": "floor",
      "text": "Considered by Senate pursuant to unanimous consent agreement of June 29, 2010.",
      "type": "action"
    },
    {
      "acted_at": "2010-06-30",
      "location": "floor",
      "text": "Confirmed by the Senate by Yea-Nay Vote. 99 - 0. Record Vote Number: 203.",
      "type": "action"
    }
  ],
  "last_action": {
    "acted_at": "2010-06-30",
    "location": "floor",
    "text": "Confirmed by the Senate by Yea-Nay Vote. 99 - 0. Record Vote Number: 203.",
    "type": "action"
  }
}
{% endhighlight %}

**actions.type**
The type of action. At this time, the only value for nomination actions is "action".

**actions.location**
Where the action occurred. Can be either "committee" or "floor".

**actions.acted_at**
The date the action occurred.

**actions.text**
Text describing the action.

**last_action**
A convenience field containing only the most recent action object.