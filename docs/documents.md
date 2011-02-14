The **documents** collection holds links to various kinds of documents produced by agencies within Congress, or agencies outside of Congress regarding legislation and related matters. 

This collection currently contains only one kind of document:

* **whip_notice** - Daily and weekly digests of chamber schedules published by House leadership of each party.

### Guaranteed fields

The only fields you can assume are always present are:

* **document_type**
* **url**
* **posted_at**

For documents of type "whip_notice", the following fields are always present:

* **notice_type**
* **chamber**
* **party**
* **for_date**

### Fields

<dt>document_type</dt>
<dd>Type of document, currently only "whip_notice".</dd>

<dt>url</dt>
<dd>URL to the document.</dd>

<dt>posted_at</dt>
<dd>(timestamp) Time the document was posted. If exact time is not known, noon UTC is assumed. **Default order for this collection.**</dd>

#### Whip notice fields

<dt>notice_type</dt>
<dd>Type of notice, one of "daily", "nightly", or "weekly".</dd>

<dt>party</dt>
<dd>Party that produced the notice, either "R" or "D".</dd>

<dt>chamber</dt>
<dd>Chamber the notice is about, either "house" or "senate".</dd>

<dt>for_date</dt>
<dd>(date) The day that the document is in reference to.</dd>

### Example

<script src="https://gist.github.com/773645.js?file=documents.json"></script>