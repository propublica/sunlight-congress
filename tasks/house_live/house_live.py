import re
import feedparser
import urllib2
import datetime
from dateutil.tz import *
import time


rss_url = "http://houselive.gov/VPodcast.php?view_id=2"

def run(db):
    add_date = datetime.datetime.now().strftime("%Y-%m-%dT%H:%Mz")
    rss = feedparser.parse(rss_url)
    count = 0
    
    for video in rss.entries:
    
        date_obj = datetime.datetime.strptime(re.sub("[-+]\d{4}", "", video.date, 1).strip(), "%a, %d %b %Y %H:%M:%S")
        timestamp_obj = datetime.datetime(date_obj.year, date_obj.month, date_obj.day, 12, 0, 0, tzinfo=gettz("America/New_York"))
        slug = int(time.mktime(timestamp_obj.timetuple()))
        
        video_id = 'house-' + str(slug)
        
        video_obj = db.get_or_initialize('videos', {'video_id': video_id})
        
        video_obj['pubdate'] = timestamp_obj.strftime("%Y-%m-%dT%H:%M%z")
        video_obj['legislative_day'] = timestamp_obj.strftime("%Y-%m-%d")
        url = video.enclosures[0]['url']
        video_obj['title'] = video.title
        video_obj['description'] = "HouseLive.gov feed for " + timestamp_obj.strftime("%B %d, %Y")
        link = video.link
        clip_id = re.search("(clip_id=)(\d+)", link).groups()[1]
        video_obj['clip_id'] = clip_id
        if video_obj.has_key('clip_urls'):
            video_obj['clip_urls']['mp4'] = url
        else:
            video_obj['clip_urls'] = {'mp4' : url }

        video_obj['created_at'] = add_date
        video_obj['chamber'] = 'house'
        
        db['videos'].save(video_obj)
        
        # print "Saved house video for %s" % video_obj['legislative_day']
        count += 1
            
    db.success("Updated or created %s live House videos" % count)

def get_mms_url(clip_id):
    clip_xml = urllib2.urlopen("http://houselive.gov/asx.php?clip_id=%s&view_id=2&debug=1" % clip_id).read()
    mms_url = re.search("(<REF HREF=\")([^\"]+)", clip_xml).groups()[1]
    return mms_url