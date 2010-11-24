import datetime
import sys
from pymongo import Connection
import traceback
from BeautifulSoup import BeautifulSoup, SoupStrainer
import urllib2
import re 

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
    db["videos"].update({"live": True}, {"$set": {"live": False }})

    url = "http://www.whitehouse.gov/live"
   # url = "http://10.13.33.209/"
    page = urllib2.urlopen(url)
    soup = BeautifulSoup(page)
    vid_list = soup.findAll('div', {"class": re.compile(r'\bviews-row\b')})
    if vid_list:
        for vid in vid_list:
            timestamp = datetime.datetime.strptime( vid.find('div', 'date').find('span').string, "%B %d, %Y %I:%M %p %Z" )
            a_tag = vid.find('h3').find('a')
            slug = a_tag['href'][a_tag['href'].rfind("/") + 1:]
            link = a_tag['href']
            title = a_tag.string
            video_id = slug + 'whitehouse'
            video_obj = get_or_create_video(db["videos"], video_id)
            video_obj['title'] = title
            video_obj['created_at'] = add_date
            video_obj['chamber'] = 'whitehouse'
            video_obj['start_time'] = timestamp
            video_obj['live'] = True
        
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
                video_obj['live'] = False

            db["videos"].save(video_obj)
    else:
        print "no live streaming"
    
