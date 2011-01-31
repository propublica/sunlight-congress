import datetime
import time
from dateutil.tz import *
from BeautifulSoup import BeautifulSoup, SoupStrainer
import urllib2
import re 


tzs = {"EST" : "America/New_York", "CST": "America/Chicago", "MST": "America/Denver", "PST": "America/Los_Angeles"}

def run(db):
    add_date = datetime.datetime.now()

    #Should start with setting live to false on all video objects
    db["videos"].update({"status": "live"}, {"$set": {"status": "archived" }})
    db["videos"].remove({"status": "upcoming"})

    url = "http://www.whitehouse.gov/live"
    # url = "http://10.13.33.209/"
    
    try:
        page = urllib2.urlopen(url).read()
        
    except:
        db.note("Couldn't load floor updates URL, can't go on")
        exit()
    
    soup = BeautifulSoup(page)
    
    content = soup.find('div', {"id" : "video-list-box"})
    
    if not content:
      db.note("Couldn't find video box on whitehouse.gov, couldn't proceed, html attached", {"html": page})
    else:
      vid_list = content.findAll('div', {"class": re.compile(r'\bviews-row\b')})
      
      if vid_list:
          count = 0
          
          for vid in vid_list:
              date = vid.find('div', "date")
              date_str = date.find("span")
              
              time_obj = vid.find('div', 'date').find('span')
              
              if not time_obj:
                db.warning("Couldn't find timestamp span tag for a whitehouse.gov video, can't proceed, video html attached", {"vid": vid.string})
                exit()
              
              timestr = time_obj.string
              
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
                  
                  video_obj = db.get_or_initialize("videos", {'video_id': video_id})
                  
                  video_obj['title'] = title
                  video_obj['created_at'] = add_date
                  video_obj['chamber'] = 'whitehouse'
                  video_obj['start_time'] = timestamp
                  video_obj['status'] = "live"
                  video_obj['pubdate'] = timestamp.strftime("%Y-%m-%dT%H:%M%z")
                  
                  # get full href from a_tag and pull that page, then parse the video tag on that page
                  this_url = "http://whitehouse.gov" + link
                  
                  try:
                      vid_page = urllib2.urlopen(this_url).read()
                  
                  except:
                      db.warning("Error loading video URL, url attached, going on to next one", {url: this_url})
                      continue
                  
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

                  db["videos"].save(video_obj, safe=True)
                  
              else:
                  title = vid.find('h3').string
                  video_obj = { "title" : title,
                                "status": "upcoming",
                                "start_time": timestamp,
                                "chamber": "whitehouse"
                              }
                  db["videos"].save(video_obj)
              
              # print "Updated or created video %s" % video_obj['title']
              count += 1
          
          db.success("Updated or created %s live White House videos" % count)
          
      else:
          db.success("No live streaming scheduled, 0 videos created.")
