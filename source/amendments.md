# Amendments

Data on amendments in Congress goes back to 2009, and comes from THOMAS.gov via scrapers at the [github.com/unitedstates](https://github.com/unitedstates/congress) project.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

```text
http://congress.api.sunlightfoundation.com
```

### /amendments

Filter through amendments in Congress. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**Senate amendments in the 113th Congress**

```text
/amendments?chamber=house&congress=113
```

**Amendments sponsored by the House Rules Committee**

```text
/amendments?sponsor_type=committee&sponsor_id=HSRU
```

**Amendments of CISPA, H.R. 624**

```text
/amendments?amends_bill_id=hr624-113
```


## Fields

**Many fields are not returned unless requested.** You can request specific fields with the `fields` parameter. See the [partial responses](index.html#parameters/partial-responses) documentation for more details.

\* = can be used as a filter

```json
{
"amendment_id": "hamdt10-113",
"amendment_type": "hamdt",
"number": 10,
"congress": 113,
"chamber": "house",
"house_number": 8,
"introduced_on": "2013-01-15",
"last_action_at": "2013-01-15T22:27:00Z"
}
```

\* **amendment_id**<br/>
The unique ID for this amendment. Formed from the `amendment_type`, `number`, and `congress`.

\* **amendment_type**<br/>
The type for this amendment. For the amendment "H.Amdt. 10", the `amendment_type` represents the "H.Amdt." part. Amendment types can be either **hamdt** or **samdt**.

\* **number**<br/>
The number for this amendment. For the amendment "H.Amdt. 10", the `number` is 10.

\* **congress**<br/>
The Congress in which this amendment was introduced. For example, amendments introduced in the "113th Congress" have a `congress` of 113.

\* **chamber**<br/>
The chamber in which the amendment was introduced.

\* **house_number**<br/>
If the amendment was introduced in the House, this is a **relative** amendment number, scoped to the bill or treaty the House it relates to. How this number gets assigned is complicated and involves multiple institutions within the House and the Library of Congress. You can read the [gory details](https://github.com/unitedstates/congress/issues/68) if you want, but this number will **usually** do the job of connecting to data from the House Clerk's [Electronic Voting System](http://clerk.house.gov/evs/2013/index.asp).

\* **introduced_on**<br/>
The date this amendment was introduced.

\* **last_action_at**<br/>
The date or time of the most recent official action on the amendment. Often, there are no official actions, in which case this field will be set to the value of `introduced_on`.

### What it Amends

```json
{
"amends_amendment_id": "hamdt5-113",
"amends_amendment": {
  "amendment_id": "hamdt5-113",
  "congress": 113,
  "number": 5
  ...
},
"amends_bill_id": "hr152-113",
"amends_bill": {
  "bill_id": "hr152-113",
  "bill_type": "hr",
  "chamber": "house"
  ...
}
}
```

An amendment will relate to either a **bill** or a **treaty**. An amendment can either amend a bill or treaty directly, or it can amend an **amendment** that amends a bill.

\* **amends_bill_id**<br/>
If this amendment relates to a bill, this field is the ID of the related bill.

**amends_bill**<br/>
If this amendment relates to a bill, some basic details about that related bill.

\* **amends_treaty_id**<br/>
If this amendment relates to a treaty, this field is the ID of the related treaty. Treaty IDs are of the form `treatyX-Y`, where X is the treaty's number, and Y is the Congress the treaty is being considered in.

\* **amends_amendment_id**<br/>
If this amendment amends an amendment, this field is the ID of the amended amendment.

**amends_amendment**<br/>
If this amendment amends an amendment, some basic details about that amended amendment.


### Sponsor

```json
{
"sponsor_type": "person",
"sponsor_id": "B000574",
"sponsor": {
  "bioguide_id": "B000574",
  "birthday": "1948-08-16",
  "chamber": "house"
  ...
}
}
```

Unlike bills, amendments can be sponsored by either a **person** or a **committee**.

\* **sponsor_type**<br/>
Whether the amendment is sponsored by a "person" or a "committee".

\* **sponsor_id**<br/>
If the `sponsor_type` is "person", this will be that person's bioguide ID. If the `sponsor_type` is "committee", this will be that committee's ID (see the [committee docs](committees.html) for information on committee IDs).

**sponsor**<br/>
If the `sponsor_type` is "person", some basic details about that person. If the `sponsor_type` is "committee", some basic details about that committee.

### Description and Purpose

```json
{
"purpose": "An amendment numbered 6 printed in Part C of House Report 113-1 to clarify that the Corps of Engineers...",
"description": "Amendment to clarify that the Corps of Engineers..."
}
```

Amendments can have a `purpose` and a `description`. It's not clear why there are two separate fields. When both are available, the `purpose` has slightly more information, but that information may be procedural and not relevant to the content of the amendment, as in the example above.

Amendments can have neither of these two fields (very common), or only a `purpose` (common), or only a `description` (common), or neither (very rare). You can read [further discussion](https://github.com/unitedstates/congress/issues/71#issuecomment-18246379) if you're interested.

### Actions

Actions on an amendment are identical to actions on bills. Please refer to the [documentation on bill actions](bills.html#fields/actions) for examples and details.