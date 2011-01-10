The **bills** collection holds all introduced bills and resolutions in Congress. 

### Bill IDs

Bill identifiers are a combination of the type of bill, the bill number, and the session of Congress a bill was introduced in.  They are of the format: 

[type][number]-[session]

For example, H.R. 4173 from the 111th Congress would be "hr4173-111".

### Guaranteed fields

The only fields you can assume are present on a bill are:

* **bill_id**
* **bill_type**
* **number**
* **session**
* **chamber**

### Text search fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **short_title**
* **official_title**
* **popular_title**
* **keywords**
* **summary**

### Types of Bills

* **hr** - House bills ("H.R.")
* **hres** - House resolutions ("H.Res")
* **hjres** - House joint resolutions ("H.J.Res")
* **hcres** - House concurrent resolutions ("H.C.Res" or "H.Con.Res")
* **s** - Senate bills ("S.")
* **sres** - Senate resolutions ("S.Res")
* **sjres** - Senate joint resolutions ("S.J.Res")
* **scres** - Senate concurrent resolutions ("S.C.Res" or "S.Con.Res")

### Fields

<dt>bill_id</dt>
<dd>Unique ID. (See above list for how to construct the ID.)</dd>

<dt>bill_type</dt>
<dd>Type of bill. (See above list for what the types mean.)</dd>

<dt>number</dt>
<dd>The number of the bill. (For example, HR 4173's number is 4173.)</dd>

<dt>session</dt>
<dd>The session of Congress this bill was introduced in.</dd>

<dt>chamber</dt>
<dd>The chamber of Congress this bill originated in.</dd>

<dt>short_title</dt>
<dd>An officially designated "short title" of a bill. Not all bills have this. (e.g. "Truth in Fur Labeling Act of 2010")</dd>

<dt>official_title</dt>
<dd>The official title of a bill. Almost all bills have one of these.</dd>

<dt>popular_title</dt>
<dd>An officially designated "popular title" (i.e. "Health care reform bill") for a bill. Very uncommon (there were 4 in the 111th Congress).</dd>

<dt>titles</dt>
<dd>An array of objects containing all short, official, and popular titles to the bill, and when the titles were made.</dd>

<dt>summary</dt>
<dd>An official summary of the bill, if the Congressional Research Service has written one.</dd>

<dt>sponsor_id</dt>
<dd>Bioguide ID for the legislator sponsoring the bill.</dd>

<dt>sponsor</dt>
<dd>Object containing basic data about the legislator sponsoring the bill.</dd>

<dt>cosponsor_ids</dt>
<dd>An array of bioguide IDs for the legislators cosponsoring the bill.</dd>

<dt>cosponsors</dt>
<dd>An array of objects containing basic data about the legislators cosponsoring the bill.</dd>

<dt>committee_ids</dt>
<dd>An array of committee IDs for committees which have some relation to this bill.</dd>

<dt>committees</dt>
<dd>An array of objects, keyed by committee ID, which give basic details about each committee that has some relation to this bill, and what kind of role the committee has in regards to it.</dd>

<dt>amendment_ids</dt>
<dd>An array of IDs of introduced amendments to this bill, that refer to documents in the amendments collection.</dd>

<dt>amendments</dt>
<dd>An array of basic information about introduced amendments to this bill.</dd>

<dt>amendments_count</dt>
<dd>The number of amendments to this bill that have been introduced.</dd>

<dt>keywords</dt>
<dd>An array of official keywords and phrases that categorize the bill.</dd>

<dt>actions</dt>
<dd>An array of all actions upon a bill, in sequence.</dd>

<dt>last_action</dt>
<dd>The last action to happen to a bill.</dd>

<dt>last_action_at</dt>
<dd>(timestamp) The time of the last action to happen to a bill.</dd>

<dt>passage_votes</dt>
<dd>An array of objects containing details on passage votes taken on the bill.</dd>

<dt>passage_votes_count</dt>
<dd>The number of passage votes taken on this bill.</dd>

<dt>last_passage_vote_at</dt>
<dd>(timestamp) Last time a passage vote was taken on a bill.</dd>

<dt>related_bills</dt>
<dd>A hash where the keys are the type of relation, and the values are arrays of bill IDs.</dd>

<dt>introduced_at</dt>
<dd>(timestamp) When a bill was introduced. **Default order for this collection.**</dd>

<dt>senate_result</dt>
<dd>The result of a Senate passage vote on the bill, if one was taken. "pass", "fail", or null.</dd>

<dt>senate_result_at</dt>
<dd>(timestamp) When the Senate last voted on passage of the bill, if it did.</dd>

<dt>house_result</dt>
<dd>The result of a House passage vote on the bill, if one was taken. "pass", "fail", or null.</dd>

<dt>house_result_at</dt>
<dd>(timestamp) When the House last voted on passage of the bill, if it did.</dd>

<dt>awaiting_signature</dt>
<dd>(boolean) Whether a bill is **currently** awaiting the president's signature. Becomes false once the bill is vetoed or enacted.</dd>

<dt>awaiting_signature_since</dt>
<dd>(timestamp) When a bill began awaiting the president's signature, if it has been. Unset once the bill is enacted or vetoed.</dd>

<dt>vetoed</dt>
<dd>(boolean) Whether a bill has been vetoed.</dd>

<dt>vetoed_at</dt>
<dd>(timestamp) When a bill was vetoed, if it was.</dd>

<dt>override_senate_result</dt>
<dd>The result of a Senate veto override vote, if one was taken. "pass", "fail", or null.</dd>

<dt>override_senate_at</dt>
<dd>(timestamp) When the Senate last voted to override a veto of the bill, if it did.</dd>

<dt>override_house_result</dt>
<dd>The result of a House veto override vote, if one was taken. "pass", "fail", or null.</dd>

<dt>override_house_at</dt>
<dd>(timestamp) When the House last voted to override a veto of the bill, if it did.</dd>

<dt>enacted</dt>
<dd>(boolean) Whether a bill has been enacted as law, through signature or a veto override.</dd>

<dt>enacted_at</dt>
<dd>(timestamp) When a bill was enacted, if it was.</dd>

#### actions

<dt>text</dt>
<dd>Text describing the action that occurred to the bill.</dd>

<dt>acted_at</dt>
<dd>(timestamp) Date or time the action occurred.</dd>

<dt>type</dt>
<dd>Type of action that occurred. Usually this is "action", but can be "vote", "vote2", "vote-aux", "signed", "topresident", "enacted", and potentially other unforeseen values.</dd>

#### passage_votes

<dt>result</dt>
<dd>Result of the vote. Either "pass" or "fail".</dd>

<dt>voted_at</dt>
<dd>(timestamp) When the vote occurred.</dd>

<dt>passage_type</dt>
<dd>What this vote signifies. Can be "vote", "vote2", "vote-aux", or "pingpong".</dd>

<dt>text</dt>
<dd>Text describing the vote.</dd>

<dt>how</dt>
<dd>How the vote was taken. Can be "roll" if it was a roll call vote, or one of several forms indicating a voice vote or unanimous consent.</dd>

<dt>roll_id</dt>
<dd>If the vote was a roll call vote, the associated roll call ID.</dd>

<dt>chamber</dt>
<dd>Chamber the vote took place in. Either "house" or "senate".</dd>

#### committees

A hash, keyed by committee ID, relating some basic information about the committee to what roles the committee had in relation to the bill.

<dt>activity</dt>
<dd>An array of activities this committee has in relation to this bill.</dd>

<dt>committee</dt>
<dd>Basic information about the committee.</dd>
