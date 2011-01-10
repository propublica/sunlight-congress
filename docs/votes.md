The **votes** collection holds all known votes taken in Congress.

### Vote IDs

Votes taken by roll call have an ID unique among roll calls:

[chamber code][roll number]-[year]

e.g. "s20-2010" for Senate Roll Call No. 20 from 2010.

There is currently no way to uniquely reference voice votes.

### Missing votes

We do not have information on voice votes taken on procedural items; only voice votes that are taken on passage of a bill or resolution. The same applies to "unanimous consent" agreements.

All roll calls, whether procedural or on passage of a bill or resolution, should be present.

### Vote types

* **passage** - On the passage of a bill or resolution.
* **cloture** - Cloture vote. Only occurs in the Senate.
* **leadership** - Vote for leadership of the chamber. Only occurs for the vote for Speaker of the House.
* **nomination** - Vote on a presidential nomination. Only occurs in the Senate.
* **quorum** - Vote to establish [quorum](http://en.wikipedia.org/wiki/Quorum#United_States). Only occurs in the House.
* **other** - All other votes.

### Vote values

* **Yea** - A vote in favor.
* **Nay** - A vote against.
* **Present** - A vote signifying only that the voter is present.
* **Not Voting** - The voter did not cast any vote.

There is one exception, which is the vote for Speaker of the House. For this vote, the vote value is either the name of the candidate, or "Present" or "Not Voting".

### Guaranteed fields

The only fields you can assume are present on every vote are:

* **session**
* **chamber**
* **year**
* **question**
* **result**
* **vote_type**
* **voted_at**
* **how**

For roll call votes, the following additional fields are always present:

* **number**
* **required**
* **roll_id**
* **roll_type**

### Text search fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **question**

### Fields

<dt>session</dt>
<dd>Session of Congress.</dd>

<dt>chamber</dt>
<dd>Chamber of Congress in which the vote took place. One of "house" or "senate".</dd>

<dt>year</dt>
<dd>The year in which the vote took place.</dd>

<dt>number</dt>
<dd>The roll call number for the vote.</dd>

<dt>vote_type</dt>
<dd>The type of the vote, as defined in the list above.</dd>

<dt>question</dt>
<dd>The question being voted upon.</dd>

<dt>result</dt>
<dd>The result of the vote. Free text field.</dd>

<dt>required</dt>
<dd>The fraction of the body which must vote Yea for the vote to pass. (e.g. "1/2", "3/5")</dd>

<dt>voted_at</dt>
<dd>(timestamp) The time at which the vote took place.</dd>

<dt>how</dt>
<dd>How the vote was taken. Can be "roll" if it was a roll call vote, or one of several forms indicating a voice vote or unanimous consent.</dd>

<dt>roll_id</dt>
<dd>Unique roll call ID, if this vote is a roll call.</dd>

<dt>roll_type</dt>
<dd>Type of roll call vote this is. (e.g. "On Passage", "On Motion to Concur", etc.)</dd>

<dt>bill_id</dt>
<dd>ID of a related bill, if there is one.</dd>

<dt>bill</dt>
<dd>Basic information about a related bill, if there is one.</dd>

<dt>voter_ids</dt>
<dd>A hash where the keys are bioguide IDs, and the values are individual votes.</dd>

<dt>voters</dt>
<dd>A hash where the keys are bioguide IDs, and the values are hashes with individual votes and basic information about each voter.</dd>

<dt>vote_breakdown</dt>
<dd>A hash containing a total breakdown of votes, as well as a breakdown of votes by party.</dd>
