The **amendments** collection holds all amendments to bills and resolutions offered in Congress.

Amendments may be offered on behalf of either a legislator or a committee.

### Amendment IDs

Amendments IDs are a combination of the chamber, the amendment number, and the session of Congress an amendment was offered in.  They are of the format: 

[chamber][number]-[session]

For example, Senate amendment no. 4850 from the 111th Congress would be "s4850-111".

### Guaranteed fields

All fields are guaranteed. All amendments should have an associated bill, an associated sponsor, and at least one action.

### Text search fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **description**
* **purpose**

### Fields

<dt>session</dt>
<dd>The session of Congress this amendment was offered during.</dd>

<dt>number</dt>
<dd>The amendment's official number.</dd>

<dt>chamber</dt>
<dd>The chamber the amendment was offered in. Either "house" or "senate".</dd>

<dt>state</dt>
<dd>The current state of the amendment. One of "fail", "offered", "pass", or "withdrawn".</dd>

<dt>offered_at</dt>
<dd>(timestamp) Time the amendment was offered. **Default order for this collection.**</dd>

<dt>description</dt>
<dd>Official description of the amendment. Not clear what distinguishes this from the "purpose" field.</dd>

<dt>purpose</dt>
<dd>Official purpose of the amendment. Not clear what distinguishes this from the "description" field.</dd>

<dt>sponsor_type</dt>
<dd>The type of sponsor of the amendment. Can be either "committee" or "legislator".</dd>

<dt>sponsor_id</dt>
<dd>Either the bioguide ID of the legislator, or the committee ID of the committee, that is sponsoring the amendment.

<dt>sponsor</dt>
<dd>An object with basic information about either the legislator or the committee that is sponsoring the amendment.</dd>

<dt>bill_id</dt>
<dd>ID of the associated bill.</dd>

<dt>bill</dt>
<dd>Basic information about the associated bill.</dd>

<dt>actions</dt>
<dd>An array of all actions upon an amendment, in sequence. Fields described below.</dd>

<dt>last_action_at</dt>
<dd>(timestamp) The time of the last action to happen to a bill.</dd>


#### actions

<dt>text</dt>
<dd>Text describing the action that occurred to the bill.</dd>

<dt>acted_at</dt>
<dd>(timestamp) Date or time the action occurred.</dd>

<dt>type</dt>
<dd>Type of action that occurred. One of "action", "vote", or "withdrawn".</dd>

### Example

Below is an example of Senate Amendment No. 4843 in the 111th Congress.

<script src="https://gist.github.com/773645.js?file=amendment.json"></script>