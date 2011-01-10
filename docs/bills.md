The **bills** collection holds all introduced bills and resolutions in Congress. 

### Bill IDs

Bill IDs are a combination of the type of bill, the bill number, and the session of Congress a bill was introduced in.  They are of the format: 

[type][number]-[session]

For example, H.R. 4173 from the 111th Congress would be "hr4173-111".

### Guaranteed fields

The only fields you can assume are present are:

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
<dd>An array of all actions upon a bill, in sequence. Fields described below.</dd>

<dt>last_action</dt>
<dd>The last action to happen to a bill.</dd>

<dt>last_action_at</dt>
<dd>(timestamp) The time of the last action to happen to a bill.</dd>

<dt>passage_votes</dt>
<dd>An array of objects containing details on passage votes taken on the bill. Fields described below.</dd>

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

### Example

This is an example for H.R. 3590, from the 111th Congress. Details have been trimmed, all fields that apply to this bill are present.

  {
    "bills": [
      {
        "actions": [
          {
            "text": "Referred to the House Committee on Ways and Means.",
            "acted_at": "2009-09-17T12:00:00Z",
            "type": "action"
          },
          {
            "text": "Became Public Law No: 111-148.",
            "acted_at": "2010-03-23T12:00:00Z",
            "type": "enacted"
          }
        ],
        "bill_type": "hr",
        "last_action": {
          "text": "Became Public Law No: 111-148.",
          "acted_at": "2010-03-23T12:00:00Z",
          "type": "enacted"
        },
        "number": 3590,
        "sponsor_id": "R000053",
        "vetoed": false,
        "cosponsors_count": 40,
        "enacted": true,
        "last_action_at": "2010-03-23T12:00:00Z",
        "senate_result_at": "2009-12-24T12:00:00Z",
        "short_title": "Patient Protection and Affordable Care Act",
        "amendments_count": 506,
        "code": "hr3590",
        "house_result_at": "2010-03-22T02:48:00Z",
        "last_vote_at": "2010-03-22T02:48:00Z",
        "passage_votes_count": 3,
        "passage_votes": [
          {
            "result": "pass",
            "passage_type": "vote2",
            "voted_at": "2009-12-24T12:00:00Z",
            "text": "Passed Senate with an amendment and an amendment to the Title by Yea-Nay Vote. 60 - 39. Record Vote Number: 396.",
            "how": "roll",
            "roll_id": "s396-2009",
            "chamber": "senate"
          },
          {
            "result": "pass",
            "passage_type": "pingpong",
            "voted_at": "2010-03-22T02:48:00Z",
            "text": "On motion that the House agree to the Senate amendments Agreed to by recorded vote: 219 - 212 (Roll no. 165).",
            "how": "roll",
            "roll_id": "h165-2010",
            "chamber": "house"
          }
        ],
        "session": 111,
        "committees": {
          "HSWM": {
            "activity": [
              "referral"
            ],
            "committee": {
              "name": "House Committee on Ways and Means",
              "committee_id": "HSWM",
              "chamber": "house"
            }
          }
        },
        "official_title": "An act entitled The Patient Protection and Affordable Care Act.",
        "titles": [
          {
            "title": "Health care reform bill",
            "type": "popular",
            "as": ""
          },
          {
            "title": "Patient Protection and Affordable Care Act",
            "type": "short",
            "as": "enacted"
          },
          {
            "title": "An act entitled The Patient Protection and Affordable Care Act.",
            "type": "official",
            "as": "amended by senate"
          }
        ],
        "committee_ids": [
          "HSWM"
        ],
        "introduced_at": "2009-09-17T12:00:00Z",
        "related_bills": {
          "unknown": [
            "hcres254-111",
            "hres1203-111",
            "hr3780-111",
            "hr4872-111",
            "s1728-111",
            "s1790-111"
          ]
        },
        "sponsor": {
          "title": "Rep",
          "nickname": "Charlie",
          "district": "15",
          "bioguide_id": "R000053",
          "govtrack_id": "400333",
          "last_name": "Rangel",
          "name_suffix": "",
          "party": "D",
          "first_name": "Charles",
          "state": "NY",
          "chamber": "house"
        },
        "awaiting_signature": false,
        "amendments": [
          {
            "sponsor_id": "A000069",
            "number": 3084,
            "last_action_at": null,
            "session": 111,
            "amendment_id": "s3084-111",
            "offered_at": "2009-12-09T12:00:00Z",
            "description": "Amendment information not available.",
            "state": "offered",
            "purpose": "Amendment information not available.",
            "chamber": "senate",
            "bill_id": "hr3590-111"
          },
          {
            "sponsor_id": "S000709",
            "number": 3175,
            "last_action_at": null,
            "session": 111,
            "amendment_id": "s3175-111",
            "offered_at": "2009-12-11T12:00:00Z",
            "description": "Amendment information not available.",
            "state": "offered",
            "purpose": "Amendment information not available.",
            "chamber": "senate",
            "bill_id": "hr3590-111"
          }
        ],
        "enacted_at": "2010-03-23T12:00:00Z",
        "house_result": "pass",
        "senate_result": "pass",
        "summary": "3/23/2010--Public Law. (This measure has not been amended since it was passed by the Senate on December 24, 2009. The summary of that version is repeated here.) Patient Protection and Affordable Care Act - Title I: Quality, Affordable Health Care for All Americans - Subtitle A: Immediate Improvements in Health Care Coverage for All Americans - (Sec. 1001, as modified by Sec. 10101) Amends the Public Health Service Act to prohibit a health plan (\"health plan” under this subtitle excludes any “grandfathered health plan” as defined in section 1251) from establishing lifetime limits or annual limits on the dollar value of benefits for any participant or beneficiary after January 1, 2014.",
        "cosponsor_ids": [
          "F000116",
          "M000312"
        ],
        "cosponsors": [
          {
            "title": "Rep",
            "nickname": "",
            "district": "51",
            "bioguide_id": "F000116",
            "govtrack_id": "400133",
            "last_name": "Filner",
            "name_suffix": "",
            "party": "D",
            "first_name": "Bob",
            "state": "CA",
            "chamber": "house"
          },
          {
            "title": "Rep",
            "nickname": "Jim",
            "district": "3",
            "bioguide_id": "M000312",
            "govtrack_id": "400263",
            "last_name": "McGovern",
            "name_suffix": "",
            "party": "D",
            "first_name": "James",
            "state": "MA",
            "chamber": "house"
          }
        ],
        "popular_title": "Health care reform bill",
        "amendment_ids": [
          "s3084-111",
          "s3175-111"
        ],
        "bill_id": "hr3590-111",
        "chamber": "house",
        "keywords": [
          "Taxation",
          "Abortion",
          "Veterans' medical care",
          "Women's health"
        ]
      }
    ],
    "page": {
      "page": 1,
      "count": 1,
      "per_page": 20
    },
    "count": 1
  }