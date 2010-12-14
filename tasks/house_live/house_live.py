import re
import feedparser
import urllib2
import datetime
from dateutil.tz import *
import time
import sys
from pymongo import Connection
import traceback

rss_url = "http://houselive.gov/VPodcast.php?view_id=2"

def get_or_create_video(coll, video_id):
    objs = coll.find({'video_id' : video_id})
    if objs.count() > 0:
        return objs[0]
    else:
        return {'video_id' : video_id}

def file_report(db, status, message, source):
    db['reports'].insert({'status': status, 'read': False, 'message':message, 'source': source, 'created_at': datetime.datetime.now() })

def get_mms_url(clip_id):
    clip_xml = urllib2.urlopen("http://houselive.gov/asx.php?clip_id=%s&view_id=2&debug=1" % clip_id).read()
    mms_url = re.search("(<REF HREF=\")([^\"]+)", clip_xml).groups()[1]
    return mms_url 
    

if len(sys.argv) > 2:
    db_host = sys.argv[1]
    db_name = sys.argv[2]
    conn = Connection(host=db_host)
    db = conn[db_name]
    
    add_date = datetime.datetime.now().strftime("%Y-%m-%dT%H:%Mz")
    rss = feedparser.parse(rss_url)
    count = 0
    
    try:
        for video in rss.entries:
        
            date_obj = datetime.datetime.strptime(re.sub("[-+]\d{4}", "", video.date, 1).strip(), "%a, %d %b %Y %H:%M:%S")
            timestamp_obj = datetime.datetime(date_obj.year, date_obj.month, date_obj.day, 12, 0, 0, tzinfo=gettz("America/New_York"))
            slug = int(time.mktime(timestamp_obj.timetuple()))
            video_id = 'house-' + str(slug)
            video_obj = get_or_create_video(db['videos'], video_id)
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
            
    except Exception as e:
        print e
        exc_type, exc_value, exc_traceback = sys.exc_info()
        file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "HouseLive")
        
    else:
        file_report(db, "SUCCESS", "Updated or created %s live House videos" % count, "HouseLive")