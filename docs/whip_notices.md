The **whip_notices** collection holds daily and weekly digests of chamber schedules published by House and Senate leadership of each party.

The contents of whip notices are not kept in the API. Each notice contains a URL to access the original document.

### Fields

<dt>notice_type</dt>
<dd>Type of notice, one of "daily", "nightly", or "weekly".</dd>

<dt>url</dt>
<dd>URL to the whip notice document.</dd>

<dt>party</dt>
<dd>Party that produced the notice, either "R" or "D".</dd>

<dt>chamber</dt>
<dd>Chamber the notice is about, either "house" or "senate".</dd>

<dt>posted_at</dt>
<dd>(timestamp) Date or time the whip notice was posted. **Default order for this collection.**</dd>

### Example

<script src="https://gist.github.com/773645.js?file=whip_notices.json"></script>
