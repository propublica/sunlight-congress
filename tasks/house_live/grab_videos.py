#main driver for daily scrape.  scrapes daily meta information for a house proceeding and saves to mongo if record doesn't already exist

from pymongo.collection import Collection
from pymongo.connection import Connection
from BeautifulSoup import BeautifulSoup, SoupStrainer
from urlparse import urlparse
import datetime, time
import urllib2
import re
import sys
import traceback

PARSING_ERRORS = []


def file_report(db, status, message, source):
    db['reports'].insert({'status': status, 'read': False, 'message':message, 'source': source, 'created_at': datetime.datetime.now() })


def get_or_create_video(coll, full_length, offset, timestamp_id):
    if full_length:
        objs = coll.find({'timestamp_id':timestamp_id})
        if objs.count() > 0:
            return objs[0]
        else:
            return {'timestamp_id':timestamp_id, 'full_length':True, 'offset':'0'}
    else:
        objs = coll.find({'timestamp_id':timestamp_id, 'offset':offset})
        if objs.count() > 0:
            return objs[0]
        else:
            return {'timestamp_id':timestamp_id, 'full_length':False, 'offset':str(offset)}

def get_or_create_floor_update(conn, timestamp, legislative_day):
    coll = conn.floor_updates
    objs = coll.find({'timestamp': timestamp, 'legislative_day': legislative_day, 'chamber': 'house'})
    if objs.count() > 0:
        return objs[0]
    else:
        return {'timestamp':timestamp, 'legislative_day': legislative_day, 'chamber': 'house'}
        

def convert_duration(hours, minutes):
    hours = int(hours)
    minutes = int(minutes)
    total_mins = (hours * 60) + minutes
    return total_mins * 60  #to get seconds

def locate_clip_id(url):
    clip_id = None
    params = urlparse(url)[4].split('&')
    for param in params:
        if param.split('=')[0] == 'clip_id':
            clip_id = param.split('=')[1]
    return int(clip_id)
 
def grab_daily_meta(db):
    url = "http://houselive.gov/ViewPublisher.php?view_id=14"
    page = urllib2.urlopen(url)
    add_date = datetime.datetime.now()
    soup = BeautifulSoup(page)
    link = soup.find('table', id="archive")

    rows = link.findAll('tr')
    for row in rows:
        cols = row.findAll('td')
        if len(cols) > 0:
            unix_time = cols[0].span.string
            fd = get_or_create_video(db['videos'], True, 0, unix_time)
            legislative_day = datetime.datetime.strptime(cols[0].contents[1] + " 12:00", '%B %d, %Y %H:%M')
            fd['legislative_day'] = legislative_day.strftime("%Y-%m-%d")
            fd['created_at'] = add_date
            duration_hours = cols[1].contents[0]
            duration_minutes = cols[1].contents[2].replace('&nbsp;', '')
            fd['duration'] = convert_duration(duration_hours, duration_minutes)
            fd['clip_id'] = locate_clip_id(cols[3].contents[2]['href'])
            fd['clip_urls'] = {
                            'mp3':  cols[4].a['href'],
                            'mp4':  cols[4].a['href'].replace('.mp3', '.mp4'),
                            'wmv':  cols[4].a['href'].replace('.mp3', '.wmv'),
                            }

            fd['clips'] = grab_daily_events(fd)
            db['videos'].save(fd)
            
def grab_daily_events(full_video):
    
    def get_timestamp(item, date, am_or_pm):
        try:
            timestamp = item.nextSibling.nextSibling.a.string
        except:
            timestamp = item.nextSibling.nextSibling.string

        try:
            minutes = int(re.findall('(?<=:)\d+', timestamp)[0])
        except Exception:
            print "couldn't parse minutes for %s" % timestamp
            return (None, date, am_or_pm)

        if re.findall('PM', timestamp):
            hours = int(re.findall('\d+(?=:)', timestamp)[0])
            if hours != 12:
                hours += 12 #convert to 24 clock
            if am_or_pm == 'AM':
                date -= datetime.timedelta(days=1) #we're into the original legislative day now
                am_or_pm = 'PM'
        else: 
            hours = int(re.findall('\d+(?=:)', timestamp)[0])
            if hours == 12:
                hours = 0  #12 am is 0 on 24 hours clock
            am_or_pm = 'AM'
        
        return (datetime.datetime(date.year, date.month, date.day, hours, minutes), date, am_or_pm)

    def add_event(obj, text, coll):
        text = text.strip()
        if obj.has_key('events'):
            obj['events'].append(text)
        else:
            obj['events'] = [text,]
        return obj
    
    def parse_group(pt, video, fu, db):
        global PARSING_ERRORS
        pt = group.findNext('p')
        while pt.name == 'p':
            if (len(pt.contents) > 0):
                text = None
                if(len(pt.contents) == 1):
                    text = pt.contents[0]
                else:
                    text = ''.join(pt.findAll(text=True)) #get rid of formatting tags
                    if pt.findAll('a'):
                        pass
                        #need to parse links here
                    #add bill ids in here somewhere
                if text:
                    video = add_event(video, text, db['videos'])
                    fu = add_event(fu, text, db['floor_updates'])
                    db['floor_updates'].save(fu)
                     
                else:
                    PARSING_ERRORS.append((video['legislative_day'], "Couldn't parse text: %s" % pt.contents))
            if hasattr(pt.nextSibling, 'name'):
                pt = pt.nextSibling
            else:
                break
        return video

    url = "http://houselive.gov/MinutesViewer.php?view_id=2&clip_id=%s&event_id=&publish_id=&is_archiving=0&embedded=1&camera_id=" % full_video['clip_id']
    page = urllib2.urlopen(url).read()
    add_date = datetime.datetime.now()
    soup = BeautifulSoup(page.replace("<p />", "</p><p>"))
    clips = []
    groups = soup.findAll('blockquote')
    #special case for first group that's before the first blockquote
    first_group = soup.find('style')
    groups.insert(0, first_group)
    last_clip = None
    global PARSING_ERRORS
    
    if groups: 
        try:
            am_or_pm = re.findall('AM|PM|A.M|P.M', groups[0].nextSibling.nextSibling.a.string)[0]
        except Exception:
            try:
                PARSING_ERRORS.append((full_video["legislative_day"], "Couldn't parse initial timestamp for %s" % groups[0].nextSibling ))
                am_or_pm = re.findall('AM|PM|A.M|P.M', groups[0].nextSibling.nextSibling.string)[0].replace('.', '')
            except Exception:
                PARSING_ERRORS.append((full_video["legislative_day"], "couldn't parse initial timestamp for %s, day not parsed" % full_video['legislative_day']))
                return

        if am_or_pm == 'AM': #finishing after midnight, record is being read in backwards
            date = datetime.datetime.fromtimestamp(float(full_video['timestamp_id'])) + datetime.timedelta(days=1)
        else:
            date = datetime.datetime.fromtimestamp(float(full_video['timestamp_id']))

        for group in groups:
            if group.nextSibling.nextSibling:
                try:
                    offset = int(group.nextSibling.nextSibling.a['onclick'].replace("top.SetPlayerPosition('0:", "").replace("',null); return false;", ""))
                except Exception:
                    offset = None
                
                timestamp, date, am_or_pm = get_timestamp(group, date, am_or_pm)
                fe = {'offset': offset, 'time': timestamp}
                fu = get_or_create_floor_update(db['floor_updates'], timestamp, full_video['legislative_day'])
                fu['created_at'] = add_date
                fu['timestamp'] = timestamp
                
                #figure out the duration for smaller clips
                if last_clip is None: 
                    #first clip read, which is last clip of day
                    if offset:
                        fe['duration'] = int(full_video['duration']) - offset
                    last_clip = fe
                else:
                    if offset:
                        fe['duration'] = int(last_clip['offset']) - offset
                        last_clip = fe

                if timestamp:
                    desc_group = group#findNext('p')
                    fe = parse_group(desc_group, fe, fu, db)
                    db['floor_updates'].save(fu)
                    clips.append(fe)
                else:
                    continue
            
            else:
                print "finished parsing %s" % full_video['legislative_day']
                #print "\n"
        return clips
    else:
        PARSING_ERRORS.append((full_video["legislative_day"], "Record empty for %s " % full_video["legislative_day"]))
    
if len(sys.argv) > 2:
    db_host = sys.argv[1]
    db_name = sys.argv[2]
    
    # further command line arguments will come in as sys.argv[3] and on up
    # e.g. 'all' will be sys.argv[3]
    
    conn = Connection(host=db_host)
    db = conn[db_name]
    
    try:
        grab_daily_meta(db)
        file_report(db, "WARNING", PARSING_ERRORS, "grab_videos")

    except Exception as e:
        exc_type, exc_value, exc_traceback = sys.exc_info()
        print "%s %s" % (e, traceback.extract_tb(exc_traceback))
        file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "grab_videos")

else:
    print 'Not enough arguments passed'
    sys.exit()
                           
