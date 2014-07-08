---
layout: default
---


* placeholder
{:toc}

# Hearings

Committee hearings scheduled by the House and Senate. This data is taken from original [House](http://house.gov/legislative/) and [Senate](http://www.senate.gov/pagelayout/committees/b_three_sections_with_teasers/committee_hearings.htm) sources.

This endpoint is future-looking. We don't automatically delete data on past hearings, but we also don't guarantee non-recent data will remain available.

## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

### /hearings

Search and filter through committee hearings in the House and Senate. Filter by any [fields below](#fields) that have a star next to them. All [standard operators](index.html#parameters/operators) apply.

**House committee hearings in DC**

{% highlight text %}
/hearings?chamber=house&dc=true
{% endhighlight %}

**Hearings about 'children'**

{% highlight text %}
/hearings?query=children
{% endhighlight %}

This will search hearings' `description` field.

## Fields

\* = can be used as a filter

Basic details about the related [committee](committees.html) will appear in the **committee** field.

{% highlight json %}
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
{% endhighlight %}


\* **committee_id**
The ID of the [committee](committees.html) holding the hearing.

\* **occurs_at**
The time the hearing will occur.

\* **congress**
The number of the Congress the committee hearing is taking place during.

\* **chamber**
The chamber ("house", "senate", or "joint") of the committee holding the hearing.

\* **dc**
Whether the committee hearing is held in DC (true) or in the field (false).

**room**
If the hearing is in DC, the building and room number the hearing is in. If the hearing is in the field, the address of the hearing.

**description**
A description of the hearing.

\* **bill_ids**
The IDs of any [bills](bills.html) mentioned by or associated with the hearing.

**url**
(House only) A permalink to that hearing's description on that committee's official website.

\* **hearing_type**
(House only) The type of hearing this is. Can be: "Hearing", "Markup", "Business Meeting", "Field Hearing".

### Committee Details

{% highlight json %}
{
  "committee": {
    "address": "2125 RHOB; Washington, DC 20515",
    "chamber": "house",
    "committee_id": "HSIF",
    "name": "House Committee on Energy and Commerce",
    "office": "2125 RHOB",
    "phone": "(202) 225-2927",
    "subcommittee" :false
  }
}
{% endhighlight %}

### House Witness Details
For house hearings, witness information is extracted from the xml.

**first_name**
First name of the witness.

**last_name**
Last name of the witness.

**middle_name**
Middle name of the witness when provided.

**organization**
Organization of the witness.

**position**
Position held by the witness.

**description**
Description of the witness document, if provided.

**published_at**
Date and time the witness document was published.

**witness_type**
Description of the witness such as Government - Federal, Non-Governmental, Government - State

**url**
The link to the original witness document.

**permalink**
A back-up copy of the witness document.

{% highlight json %}
witnesses: [
  {
    first_name: "Phil",
    last_name: "McGraw",
    middle_name: null,
    organization: "Dr. Phil",
    position: "Talk Show Host",
    witness_type: "Non-Governmental",
    documents: [
      {
        description: null,
        published_at: "2014-05-29T18:50:22Z",
        type: "Witness statement",
        url: "http://docs.house.gov/meetings/WM/WM03/20140529/102278/HHRG-113-WM03-Wstate-McGrawP-20140529.pdf",
        permalink: "http://unitedstates.sunlightfoundation.com/congress/committee/meetings/house/1022/102278/HHRG-113-WM03-Wstate-McGrawP-20140529.pdf"
      }
    ]
  },
]
{% endhighlight %}

### Meeting documents
(House only) Informaion about the documents related to hearings.

**description**
Description of the document, if provided.

**published_at**
Date and time the document was published.

**type**
This is extrapolated from the House XML document type codes. 

For example: "CV"- Committee vote; "WS"- Witness statement; "WT"- Witness truth statement; "WB"- Witness biography; "CR"- Committee report; "BR"- Bill; "FA"- Floor amendment; "CA"- Committee amendment, "HT"-  Transcript; "WD"- Witness document; "CV"- Committee vote; "WS"- Witness statement, "WT"- Witness truth statement; "WB"- Witness biography; "CR"- Committee report; "BR"- Bill; "FA- Floor amendment; "CA"- Committee amendment; "HT"- Transcript; "WD"- Witness document; "Other" is used for all other codes

**version_code**
The short-code for what stage the version of the bill is at.

**bioguide_id**
If a Member of congress is affiliated with the document, their bioguide should appear here. 

**bill_id**
A bill id for the document, if provided. 

**url**
The link to the original document.

**permalink**
A back-up copy of the document.

An example of meeting documents:
{% highlight json %}
meeting_documents: [
  {
    description: "FY 2015 Military Construction and Veterans Affairs Bill - Full Committee Draft",
    published_at: "2014-04-08T13:57:39Z",
    type: "Bill",
    version_code: "pih",
    bioguide_id: null,
    bill_id: null,
    url: "http://docs.house.gov/meetings/AP/AP00/20140409/102117/BILLS-113HR-FC-AP-FY2015-AP00-MilCon.pdf",
    permalink: "http://unitedstates.sunlightfoundation.com/congress/committee/meetings/house/1021/102117/BILLS-113HR-FC-AP-FY2015-AP00-MilCon.pdf"
  },
  {
    description: "FY 2015 Military Construction and Veterans Affairs Bill - Draft Committee Report",
    published_at: "2014-04-08T13:57:39Z",
    type: "Committee report",
    version_code: "ih",
    bioguide_id: null,
    bill_id: "hr-fy2015-milcon-113",
    url: "http://docs.house.gov/meetings/AP/AP00/20140409/102117/HRPT-113-HR-FY2015-MilCon.pdf",
    permalink: "http://unitedstates.sunlightfoundation.com/congress/committee/meetings/house/1021/102117/HRPT-113-HR-FY2015-MilCon.pdf"
  },
  {
    description: "FY2015 Military Construction/VA Bill - Adopted Amendment-Culberson",
    published_at: "2014-04-10T14:28:11Z",
    type: "Committee amendment",
    version_code: "ih",
    bioguide_id: "C001048",
    bill_id: null,
    url: "http://docs.house.gov/meetings/AP/AP00/20140409/102117/BILLS-113-HR-FC-AP-FY2015-AP00-Amdt-1.pdf",
    permalink: "http://unitedstates.sunlightfoundation.com/congress/committee/meetings/house/1021/102117/BILLS-113-HR-FC-AP-FY2015-AP00-Amdt-1.pdf"
  },
]
{% endhighlight %}

**hearing_id**
A hash id for the hearing. For the House, the hearing_id is a MD5 hash of the House Event ID, a unique identifier used for the hearing. For Senate hearings, the hearing_id is a MD5 hash of the date, Committee ID and Subcommittee ID. 

**house_event_id**
A unique identifier assigned by the House to identify a hearing.


Please note that if the witness is not identified as being attached to a document in the witness list XML, the documents will show up as meeting documents.

We are working on expanding our offering of Senate documents and hearing information. The House Committee materials are provided through the centralized and machine readable offerings of the [docs.house.gov](http://docs.house.gov/) Committee Repository. 
