The **floor_updates** collection holds updates from the floor of each chamber of Congress.

**NOTE**: The quality of floor updates for the Senate is not good. It pulls a list of speakers for the day from a page maintained by the [Republican Senate Caucus](http://republican.senate.gov/public/index.cfm?FuseAction=FloorUpdates.Home), but doesn't pull any of the descriptions or quotes therein.

### Guaranteed fields

The only fields you can assume are present are:

* **events**
* **chamber**
* **timestamp**
* **legislative_day**

### Text search fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **events**

### Fields

<dt>chamber</dt>
<dd>The chamber whose floor this update is from. Either "house" or "senate".</dd>

<dt>timestamp</dt>
<dd>(timestamp) Time this floor update occurred.</dd>

<dt>legislative_day</dt>
<dd>(date) The legislative day this floor update occurred. A "legislative day" can run longer than 24 hours, and does not conclude until the chamber is adjourned.</dd>

<dt>events</dt>
<dd>An array of events that occurred at this time.</dd>

<dt>bioguide_ids</dt>
<dd>An array of bioguide IDs of legislators mentioned in this floor update. **Note**: if the name is ambiguous and could refer to more than one person, bioguide IDs for all possible candidates will be listed. There could be false positives, but no one should be missed.</dd>

<dt>bill_ids</dt>
<dd>An array of IDs of bills mentioned in this floor update.</dd>

<dt>roll_ids</dt>
<dd>An array of IDs of roll call votes mentioned in this floor update.</dd>

### Example

Below is an example of three updates from the House floor, from the beginning of the 112th Congress.

<script src="https://gist.github.com/773645.js?file=floor_updates.json"></script>