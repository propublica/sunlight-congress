import feedparser
import datetime
from dateutil.tz import *
import re
import time
import sys
from pymongo import Connection
import traceback

feeds = [   "http://www.whitehouse.gov/podcast/video/weekly-addresses/rss.xml", 
            "http://www.whitehouse.gov/podcast/video/press-briefings/rss.xml", 
            "http://www.whitehouse.gov/podcast/video/speeches/rss.xml", 
            "http://www.whitehouse.gov/podcast/video/white-house-features/rss.xml", 
            "http://www.whitehouse.gov/podcast/video/west-wing-week/rss.xml",  
            "http://www.whitehouse.gov/podcast/video/the-first-lady/rss.xml", 
            "http://www.whitehouse.gov/podcast/video/music-and-the-arts-at-the-white-house/rss.xml",  
            "http://www.whitehouse.gov/podcast/video/open-for-questions/rss.xml" 
        ]
cats =  [   "Weekly Addresses",
            "Press Briefings",
            "Speeches",
            "Features",
            "West Wing Week",
            "The First Lady",
            "Music and Arts at the White House",
            "Open For Questions"
        ]

def get_or_create_video(coll, video_id):
    objs = coll.find({'video_id' : video_id})
    if objs.count() > 0:
        return objs[0]
    else:
        return {'video_id' : video_id}

def file_report(db, status, message, source):
    db['reports'].insert({'status': status, 'read': False, 'message':message, 'source': source, 'created_at': datetime.datetime.now() })

if len(sys.argv) > 2:
    db_host = sys.argv[1]
    db_name = sys.argv[2]
    conn = Connection(host=db_host)
    db = conn[db_name]
    add_date = datetime.datetime.now().strftime("%Y-%m-%dT%H:%MZ")
    count = 0
    
    for f in feeds:
        rss = feedparser.parse(f)
        for video in rss.entries:
            try:
                slug = video.link[video.link.rfind("/") + 1:]
                date_obj = datetime.datetime.strptime(re.sub("[-+]\d{4}", "", video.date, 1).strip(), "%a, %d %b %Y %H:%M:%S")
                date_obj = datetime.datetime(date_obj.year, date_obj.month, date_obj.day, date_obj.hour, date_obj.minute, tzinfo=gettz("America/New_York"))
                timestamp = int(time.mktime(date_obj.timetuple()))
                video_id = 'whitehouse-' + str(timestamp) + "-" + slug
                video_obj = get_or_create_video(db['videos'], video_id)
                url = video.enclosures[0]['url']
                video_obj['title'] = video.title
                video_obj['description'] = video.description
                if video_obj.has_key('clip_urls'):
                    video_obj['clip_urls']['mp4'] = url
                else:
                    video_obj['clip_urls'] = {'mp4' : url }
                video_obj['created_at'] = add_date
                video_obj['chamber'] = 'whitehouse'
                video_obj['pubdate'] = date_obj.strftime("%Y-%m-%dT%H:%M%z")
                video_obj['category'] = cats[feeds.index(f)]
                video_obj['status'] = "archived"
                db['videos'].save(video_obj)
                
                # print "Saved White House video for %s" % video_obj['pubdate']
                count += 1

            except Exception as e:
                print e
                exc_type, exc_value, exc_traceback = sys.exc_info()
                file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "WhitehouseArchive")
                
    file_report(db, "SUCCESS", "Updated or created %s White House videos" % count, "WhitehouseArchive")