The **videos** collection currently holds videos from the U.S. House of Representatives and from the White House.

There are different fields available for White House Videos, Live White House Streams, and House video. These can be distinguished using the **chamber** field.

### House of Representatives video

Filter the "chamber" field by "house" to retrieve videos from the House of Representatives.

HouseLive.gov provides full length videos of each legislative day. These videos can be extremely long, upwards of 14 hours sometimes. Each full length video has a video object in the RTC API. 

For videos that have time offsets in their corresponding floor updates, we have artificially broken up the video into an array of clip objects. These clips each have an offset (in seconds), duration, array of events covered in that clip, and extracted names and identifiers.

#### Legislator and bill extraction

Each video document, as well as each clip within it, have had their text contents scanned for legislator names and bill codes. The "legislator_names", "bioguide_ids", and "bills" fields contain these values. When present on the top-level object, they contain all values found within any of the clips for that video. When present on a clip, they contain all values found within the events for that clip.

Raw text is only added to this "legislator_names" field, and subsequently converted into bioguide IDs, if it can be matched with a representative. If a legislator name is ambiguous and could match more than one legislator, bioguide IDs for each match are added. So, the API may have "false positives" in its bioguide IDs, but it should rarely miss anyone.

#### Guaranteed Fields

The only fields guaranteed for House videos are:

* **video_id**
* **legislative_day**
* **clip_id**
* **chamber**

####  Text Search Fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **clips.events**

####  Fields

<dt>video_id</dt>
<dd>A unique id for this video in the api. It is constructed from the chamber name and the UTC timestamp on noon of the legislative day for this video</dd>

<dt>chamber</dt>
<dd>The chamber whose floor this video is from. Possible values: "house", "whitehouse".</dd>

<dt>pubdate</dt>
<dd>The published date of this video in the HouseLive.gov RSS feed</dd>

<dt>duration</dt>
<dd>The duration (in seconds) of this video</dd>

<dt>clip_id</dt>
<dd>A unique identifier for clips on the HouseLive.gov site</dd>

<dt>legislator_names</dt>
<dd>An array of strings where each string is the raw text of a legislator name that was parsed from at least once from the floor updates for this video.</dd>

<dt>bioguide_ids</dt>
<dd>An array of bioguide ids for all the legislators mentioned in the clip events of this video</dd>

<dt>bills</dt>
<dd>An array of bill ids for all the bills mentioned in the clip events of this video.</dd>

<dt>clip_urls</dt>
<dd>An object containing key value pairs for formats and URLs. Current keys include "mp4", "wmv", "mms", "mp3".</dd>

<dt>clips</dt>
<dd>An array of clip objects. The contents of each clip are defined below.

#### clips

<dt>time</dt>
<dd>UTC timestamp marking the beginning of the clip.</dd>

<dt>duration</dt>
<dd>The duration (in seconds) of this clip.</dd>

<dt>events</dt>
<dd>An array of strings documenting what occurs in this clip.</dd>

<dt>offset</dt>
<dd>The offset (in seconds) from the beginning of the main video to the start of this clip.</dd>

<dt>legislator_names</dt>
<dd>An array of strings where each string is the raw text of a legislator name that was parsed from from the events for this clip. Raw text is only added to this array if it can be matched with a representative.</dd>

<dt>bioguide_ids</dt>
<dd>An array of bioguide IDs for all the legislators mentioned in the events of this clip.</dd>

<dt>bills</dt>
<dd>An array of bill IDs for all bills mentioned in the events of this clip.</dd>

### White House videos

Filter the "chamber" field by "house" to retrieve videos from the House of Representatives.

White House video is parsed from [WhiteHouse.gov](http://www.whitehouse.gov/live). Most videos are available as "archived" videos, but some are available as "live" videos. Live videos tend to not have as many fields completed as archived videos but you can filter on the "status" field to get only live or archived videos.

#### Guaranteed Fields

The only fields guaranteed for house videos are 

* **video_id**
* **chamber**
* **pubdate**

#### Text Search Fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **title**
* **description**

### Fields

<dt>video_id</dt>
<dd>A unique id for this video in the API. It is constructed from the chamber name and the slug on the White House site in the url for this video.</dd>

<dt>category</dt>
<dd>A string denoting the category to which the video belongs. These correspond to the eight different categorical RSS feeds found on the White House site. Values include "The First Lady", "Open for Questions", "Weekly Addresses", "Press Briefings", "Speeches", "Features", "West Wing Week", "Music and Arts at the White House"</dd>

<dt>pubdate</dt>
<dd>The UTC timestamp for when this video was published.</dd>

<dt>title</dt>
<dd>A string with the video title.</dd>

<dt>description</dt>
<dd>A string with the video description.</dd>

<dt>status</dt>
<dd>String denoting the status of video. Options are "live", "archived", and "upcoming".</dd>

<dt>chamber</dt>
<dd>The chamber whose floor this video is from. Possible values: "house", "whitehouse".</dd>

<dt>clip_urls</dt>
<dd>An object containing key value pairs for formats and URLs. Current keys include "mp4", "m4v". Note that despite the m4v extensions, these files do not have DRM and are public domain.</dd>

#### Examples

An example of an archived video from HouseLive.gov is below, followed by an example of all three kinds of White House videos (upcoming, live, and archived):

<script src="https://gist.github.com/773645.js?file=videos-house.json"></script>

<script src="https://gist.github.com/773645.js?file=videos-whitehouse.json"></script>
