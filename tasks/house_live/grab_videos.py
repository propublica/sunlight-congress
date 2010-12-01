import re
import feedparser
import datetime
import time
import sys
from pymongo import Connection
import traceback

rss_url = "http://houselive.gov/VPodcast.php?view_id=2"


def get_or_create_video(coll, clip_id):
    objs = coll.find({'clip_id' : clip_id})
    if objs.count() > 0:
        return objs[0]
    else:
        return {'clip_id' : clip_id}

def file_report(db, status, message, source):
    db['reports'].insert({'status': status, 'read': False, 'message':message, 'source': source, 'created_at': datetime.datetime.now() })

if len(sys.argv) > 2:
    db_host = sys.argv[1]
    db_name = sys.argv[2]
    conn = Connection(host=db_host)
    db = conn[db_name]
    add_date = datetime.datetime.now()
    
    rss = feedparser.parse(rss_url)
    for video in rss.entries:
        try:
            date_obj = datetime.datetime.strptime(re.sub("[-+]\d{4}", "", video.date, 1).strip(), "%a, %d %b %Y %H:%M:%S")
            timestamp_obj = datetime.datetime(date_obj.year, date_obj.month, date_obj.day, 12, 0, 0)
            slug = int(time.mktime(timestamp_obj.timetuple()))
            video_id = 'house-' + str(slug)
            video_obj = get_or_create_video(db['videos'], video_id)
            video_obj['pubdate'] = video.date
            url = video.enclosures[0]['url']
            video_obj['title'] = video.title
            video_obj['description'] = "HouseLive.gov feed for " + timestamp_obj.strftime("%B %d, %Y")
            if video_obj.has_key('clip_urls'):
                video_obj['clip_urls']['mp4'] = url
            else:
                video_obj['clip_urls'] = {'mp4' : url }
            video_obj['created_at'] = add_date
            video_obj['chamber'] = 'house'
            db['videos'].save(video_obj)

        except Exception as e:
            print e
            exc_type, exc_value, exc_traceback = sys.exc_info()
            file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "grab_videos")

