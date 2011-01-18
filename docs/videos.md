The **videos** collection currently holds videos from the U.S. House of Representatives and from the White House.

There are different fields available for White House Videos, Live White House Streams, and House video. These can be distinguished using the **chamber** field.

## House of Representatives video



HouseLive.gov provides full length videos of each legislative day. These videos can be extremely long, upwards of 14 hours sometimes. Each full length video has a video object in the RTC API. For videos that have time offsets in their corresponding floor updates, we have artificially broken up the video into a clips array. These clips each have an offset (in seconds), duration, array of events covered in that clip, and 

### Guaranteed Fields

The only fields guaranteed for House videos are:

* **video_id**
* **legislative_day**
* **clip_id**
* **chamber**

###  Text Search Fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **clips.events**

###  Fields

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
<dd>An array of strings where each string is the raw text of a legislator name that was parsed from at least once from the floor updates for this video. Raw text is only added to this array if it can be matched with a representative.</dd>

<dt>bioguide_ids</dt>
<dd>An array of bioguide ids for all the legislators mentioned in the clip events of this video</dd>

<dt>bills</dt>
<dd>An array of bill ids for all the bills mentioned in the clip events of this video</dd>

<dt>clip_urls</dt>
<dd>An object containing key value pairs for formats and URLs. Current keys include "mp4", "wmv", "mms", "mp3".</dd>

<dt>clips</dt>
<dd>An array of clip objects. The contents of each clip are defined below.

#### clips

<dt>time</dt>
<dd>UTC timestamp marking the beginning of the clip</dd>

<dt>duration</dt>
<dd>The duration (in seconds) of this clip</dd>

<dt>events</dt>
<dd>An array of strings that are notes for this time in the house floor updates</dd>

<dt>offset</dt>
<dd>The offset (in seconds) from the beginning of the main video to the start of this clip</dd>


### Example


## White House videos

White House video is parsed from the White House' website. Most videos are available as archived videos, but some are available as live videos. Live videos tend to not have as many fields completed as archived videos but you can filter on the "status" field to get only live or archived videos.

### Guaranteed Fields

The only fields guaranteed for house videos are 

* **video_id**
* **chamber**
* **pubdate**

### Text Search Fields

If the "search" parameter is passed to the API, a case-insensitive pattern match of the given string is applied to the following fields:

* **title**
* **description**

### Fields

<dt>video_id</dt>
<dd>A unique id for this video in the api. It is constructed from the chamber name and the slug on the White House site in the url for this video</dd>

<dt>category</dt>
<dd>A string denoting the category to which the video belongs. These correspond to the eight different categorical RSS feeds found on the White House site. Values include "The First Lady", "Open for Questions", "Weekly Addresses", "Press Briefings", "Speeches", "Features", "West Wing Week", "Music and Arts at the White House"</dd>

<dt>pubdate</dt>
<dd>The UTC timestamp for when this video was published</dd>

<dt>title</dt>
<dd>A string with the video title</dd>

<dt>description</dt>
<dd>A string with the video description</dd>

<dt>status</dt>
<dd>String denoting the status of video. Options are "live", "archived".</dd>

<dt>chamber</dt>
<dd>The chamber whose floor this video is from. Possible values: "house", "whitehouse".</dd>

<dt>clip_urls</dt>
<dd>An object containing key value pairs for formats and URLs. Current keys include "mp4", "m4v". Note that despite the m4v extensions, these files do not have DRM and are public domain.</dd>

###  Examples


