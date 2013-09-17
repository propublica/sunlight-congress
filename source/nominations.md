# Nominations

Nominations made by the President and referred to the Senate for consideration. This data is taken from [THOMAS.gov's nominations directory](http://thomas.loc.gov/home/nomis.html), and goes back to 2009.

Data is collected using the [unitedstates/congress](https://github.com/unitedstates/congress) project. Feel free to [open a ticket](https://github.com/unitedstates/congress/issues/new) with any bugs or suggestions.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

```text
http://congress.api.sunlightfoundation.com
```

### /nominations

Search and filter through presidential nominations in Congress. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Recent nominations**

```text
/nominations?order=received_on
```

**Nominations before the Senate Armed Services Committee**

```text
/nominations?committee_ids=SSAS
```

**Nominees to the Privacy and Civil Liberties Oversight Board**

```text
/nominations?organization=Privacy and Civil Liberties Oversight Board
```

**Nominees named 'Petraeus'**

```text
/nominations?query=Petraeus
```

## Fields

**Many fields are not returned unless requested.** You can request specific fields with the `fields` parameter. See the [partial responses](index.html#parameters/partial-responses) documentation for more details.

\* = can be used as a filter

```json
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
```

\* **nomination_id**</br>
The unique identifier for this nomination, taken from the Library of Congress. Of the form "PN[number]-[congress]".

\* **congress**<br/>
The Congress in which this nomination was presented.

\* **number**<br/>
The number of this nomination, taken from the Library of Congress. Can occasionally contain hyphens, e.g. "PN64-01".

\* **received_on**<br/>
The date this nomination was received in the Senate.

\* **last_action_at**<br/>
The date this nomination last received action. If there are no official `actions`, then this field will fall back to the value of `received_on`.

\* **organization**<br/>
The organization the nominee would be appointed to, if confirmed.

\* **committee_ids**<br/>
An array of IDs of [committees](committees.html) that the nomination has been referred to for consideration.

\* **nominees**<br/>
An array of objects with fields (described below) about each nominee. Nominations for civil posts tend to have only one nominee. Nominations for military posts tend to have batches of multiple nominees. In either case, the `nominees` field will always be an array.

**nominees.name**<br/>
The name of the nominee, as it appears in THOMAS. Capitalization is not consistent.

\* **nominees.position**<br/>
The position the nominee is being nominated for.

\* **nominees.state**<br/>
The which state in the United States this nominee hails from. This field is only available for some nominees, and never for batches of multiple nominees.


## Action history

```json
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
```

**actions.type**<br/>
The type of action. At this time, the only value for nomination actions is "action".

**actions.location**<br/>
Where the action occurred. Can be either "committee" or "floor".

**actions.acted_at**<br/>
The date the action occurred.

**actions.text**<br/>
Text describing the action.

**last_action**<br/>
A convenience field containing only the most recent action object.