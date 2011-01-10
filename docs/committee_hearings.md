The **committee_hearings** collection holds upcoming and past scheduled committee hearings in the House and Senate.

### Guaranteed Fields

The only fields you can assume are present are:

* **legislative_day**
* **committee_id**
* **chamber**
* **description**

### Text search fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **description**

### Fields

<dt>chamber</dt>
<dd>Chamber the hearing takes place in. Either "house" or "senate".</dd>

<dt>description</dt>
<dd>The subject matter of the hearing.</dd>

<dt>legislative_day</dt>
<dd>(date) The day of the hearing.</dd>

<dt>occurs_at</dt>
<dd>(timestamp) The time of the hearing. **Default order for this collection.**</dd>

<dt>time_of_day</dt>
<dd>The time of day the hearing is scheduled for. Could also be "TBD".</dd>

<dt>committee_id</dt>
<dd>The ID of the committee that is holding the hearing.</dd>

<dt>committee</dt>
<dd>Basic information about the committee that is holding the hearing.</dd>

<dt>room</dt>
<dd>The building and room code for where the hearing is taking place.</dd>
