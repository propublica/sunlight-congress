# Hearings

Committee hearings scheduled by the House and Senate. This data is taken from original [House](http://house.gov/legislative/) and [Senate](http://www.senate.gov/pagelayout/committees/b_three_sections_with_teasers/committee_hearings.htm) sources.

This data is not limited only to upcoming hearings, but historical data on committee hearings is not guaranteed.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

```text
http://congress.api.sunlightfoundation.com
```

### /hearings

Search and filter through committee hearings in the House and Senate. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**House committee hearings in DC**

```text
/hearings?chamber=house&dc=true
```

**Hearings about 'children'**

```text
/hearings?query=children
```

This will search hearings' `description` field.

## Fields

\* = can be used as a filter

```json
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
```

\* **committee_id**<br/>
The ID of the [committee](committees.html) holding the hearing.

\* **occurs_at**<br/>
The time the hearing will occur.

\* **congress**<br/>
The number of the Congress the committee hearing is taking place during.

\* **chamber**<br/>
The chamber of the committee holding the hearing. "house", "senate", or "joint".

\* **dc**<br/>
Whether the committee hearing is held in DC (true) or in the field (false).

\* **room**<br/>
If the hearing is in DC, the building and room number the hearing is in. If the hearing is in the field, the address of the hearing.

**description**<br/>
A description of the hearing.

\* **bill_ids**<br/>
The IDs of any bills mentioned by or associated with the hearing.

\* **url**<br/>
(House only) A permalink to that hearing's description on that committee's official website.

\* **hearing_type**<br/>
(House only) The type of hearing this is. Can be: "Hearing", "Markup", "Business Meeting", "Field Hearing".

### Committee Details

```json
{
"committee": {
  "address": "2125 RHOB; Washington, DC 20515",
  "chamber": "house",
  "committee_id": "HSIF",
  "house_committee_id": "IF",
  "name": "House Committee on Energy and Commerce",
  "office": "2125 RHOB",
  "phone": "(202) 225-2927",
  "subcommittee" :false
}
}
```

Basic details about the related committee will appear in the **committee** field.