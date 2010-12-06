import datetime
import time
from dateutil.tz import *
import sys
from pymongo import Connection
import traceback
from BeautifulSoup import BeautifulSoup, SoupStrainer
import urllib2
import re 

tzs = { "EST" : "America/New_York", "CST": "America/Chicago", "MST": "America/Denver", "PST": "America/Los_Angeles" }

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
    add_date = datetime.datetime.now()

    #Should start with setting live to false on all video objects
    db["videos"].update({"status": "live"}, {"$set": {"status": "archived" }})
    db["videos"].remove({"status": "upcoming"})

    url = "http://www.whitehouse.gov/live"
   # url = "http://10.13.33.209/"
    page = urllib2.urlopen(url)
    soup = BeautifulSoup(page)
    content = soup.find('div', {"id" : "video-list-box"})
    vid_list = content.findAll('div', {"class": re.compile(r'\bviews-row\b')})
    if vid_list:
        for vid in vid_list:
            date = vid.find('div', "date")
            date_str = date.find("span")
            timestr = vid.find('div', 'date').find('span').string
            try:
                tz = re.findall("[A-Z]{3}", timestr)[0]
            except:
                tz = "EST"
            timestamp = datetime.datetime.strptime(timestr.replace(tz, "").strip(), "%B %d, %Y %I:%M %p" )
            timestamp = datetime.datetime(timestamp.year, timestamp.month, timestamp.day, timestamp.hour, timestamp.minute, tzinfo=gettz(tzs[tz])) #use this because datetime.replace not working for tzinfo???
            a_tag = vid.find('h3').find('a')
            if a_tag:
                slug = a_tag['href'][a_tag['href'].rfind("/") + 1:]
                link = a_tag['href']
                title = a_tag.string
                time_key = int(time.mktime(timestamp.timetuple()))
                video_id = 'whitehouse-' + str(time_key) + '-' + slug
                video_obj = get_or_create_video(db["videos"], video_id)
                video_obj['title'] = title
                video_obj['created_at'] = add_date
                video_obj['chamber'] = 'whitehouse'
                video_obj['start_time'] = timestamp
                video_obj['status'] = "live"
                video_obj['pubdate'] = timestamp.strftime("%Y-%m-%dT%H:%M%z")

            
                # get full href from a_tag and pull that page, then parse the video tag on that page
                this_url = "http://whitehouse.gov" + link
                vid_page = urllib2.urlopen(this_url)
                vid_soup = BeautifulSoup(vid_page)
                vid_tag = vid_soup.find('video')
                if vid_tag:
                    live_url = vid_tag['src']
                    if video_obj.has_key('clip_urls'):
                        video_obj['clip_urls']['hls'] = live_url 
                    else:
                        video_obj['clip_urls'] = { 'hls': live_url }
                else:
                    video_obj['status'] = ''

                db["videos"].save(video_obj)
            else:
                title = vid.find('h3').string
                video_obj = { "title" : title,
                              "status": "upcoming",
                              "start_time": timestamp,
                              "chamber": "whitehouse"
                            }
                db["videos"].save(video_obj)
    else:
        print "no live streaming"
    
