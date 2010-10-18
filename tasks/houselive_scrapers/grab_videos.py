#main driver for daily scrape.  scrapes daily meta information for a house proceeding and saves to mongo if record doesn't already exist

from pymongo.collection import Collection
from pymongo.connection import Connection
from BeautifulSoup import BeautifulSoup, SoupStrainer
from urlparse import urlparse
import datetime, time
import urllib2
import re
import sys

def get_or_create_video(coll, full_length, offset, timestamp_id):
    if full_length:
        objs = coll.find({'timestamp_id':timestamp_id})
        if objs.count() > 0:
            return objs[0]
        else:
            return {'timestamp_id':timestamp_id, 'full_length':'true', 'offset':0}
    else:
        objs = coll.find({'timestamp_id':timestamp_id, 'offset':offset})
        if objs.count() > 0:
            return objs[0]
        else:
            return {'timestamp_id':timestamp_id, 'full_length':'false', 'offset':offset}

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
 
def grab_daily_meta(coll):
    url = "http://houselive.gov/ViewPublisher.php?view_id=14"
    page = urllib2.urlopen(url)
    add_date = datetime.datetime.now()
    soup = BeautifulSoup(page)
    link = soup.find('table', id="archive")

    rows = link.findAll('tr')
    for row in rows:
        cols = row.findAll('td')
        if len(cols) > 0:
            unix_time = int(cols[0].span.string)
            fd = get_or_create_video(coll, True, 0, unix_time)
            fd['day'] = datetime.datetime.strptime(cols[0].contents[1], '%B %d, %Y')
            fd['add_date'] = add_date
            duration_hours = cols[1].contents[0]
            duration_minutes = cols[1].contents[2].replace('&nbsp;', '')
            fd['duration'] = convert_duration(duration_hours, duration_minutes)
            fd['clip_id'] = locate_clip_id(cols[3].contents[2]['href'])
            fd['mp3_url'] = cols[4].a['href']
            fd['mp4_url'] = fd['mp3_url'].replace('.mp3', '.mp4')
            fd['wmv_url'] = fd['mp3_url'].replace('.mp3', '.wmv')
            fd['offset'] = 0
            coll.save(fd)

            grab_daily_events(fd)
            
def grab_daily_events(video):
    
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

    def parse_group(pt, video):
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
                if text:
                    #add bill ids in here somewhere
                    if video.has_key('events'):
                        video['events'].append(text.strip())
                    else:
                        video['events'] = [text.strip(),]
                    try:
                        coll.save(video)
                    except Exception as e:
                        print fe
                        print pt
                        print "could not save, %s" % e
                    
                else:
                    print "can't parse text "
                    print pt.contents
            if hasattr(pt.nextSibling, 'name'):
                pt = pt.nextSibling
            else:
                break

    #proceeding = Video.query.get(fd_unix_time) #FloorDate.query.filter_by(clip_id=clip_id).first() # None #needs completion
    url = "http://houselive.gov/MinutesViewer.php?view_id=2&clip_id=%s&event_id=&publish_id=&is_archiving=0&embedded=1&camera_id=" % video['clip_id']
    page = urllib2.urlopen(url).read()
    add_date = datetime.datetime.now()
    soup = BeautifulSoup(page.replace("<p />", "</p><p>"))
    try:
       date_field = soup.findAll(text=re.compile('LEGISLATIVE DAY OF'))[0].strip()
    except Exception as e:
        print "couldn't find date for FloorDate %s" % video['day']
        return

    date_string = time.strftime("%m/%d/%Y", time.strptime(date_field.replace('LEGISLATIVE DAY OF ', '').strip(), "%B %d, %Y"))
    groups = soup.findAll('blockquote')
    #special case for first group that's before the first blockquote
    first_group = soup.find('style')
    groups.insert(0, first_group)
    
    try:
        am_or_pm = re.findall('AM|PM|A.M|P.M', groups[0].nextSibling.nextSibling.a.string)[0]
    except Exception:
        print groups[0].nextSibling.nextSibling.string
        try:
            am_or_pm = re.findall('AM|PM|A.M|P.M', groups[0].nextSibling.nextSibling.string)[0].replace('.', '')
        except Exception:
            print "couldn't parse timestamp for %s" % groups[0].nextSibling.nextSibling
            return

    if am_or_pm == 'AM': #finishing after midnight, record is being read in backwards
        date = datetime.datetime.fromtimestamp(float(video['timestamp_id'])) + datetime.timedelta(days=1)
    else:
        date = datetime.datetime.fromtimestamp(float(video['timestamp_id']))

    for group in groups:
        if group.nextSibling.nextSibling:
            try:
                offset = int(group.nextSibling.nextSibling.a['onclick'].replace("top.SetPlayerPosition('0:", "").replace("',null); return false;", ""))
            except Exception:
                offset = None
            timestamp, date, am_or_pm = get_timestamp(group, date, am_or_pm)
            fe = get_or_create_video(coll, False, offset, video['timestamp_id'])
            fe['add_date'] = add_date
            fe['timestamp_id'] = video['timestamp_id']
            fe['time'] = timestamp
            if timestamp:
                desc_group = group#findNext('p')
                parse_group(desc_group, fe)
                coll.save(fe)
            else:
                continue
        
        else:
            print "no a tag"
            print group.nextSibling
            #print "\n"
 
 
 
if len(sys.argv) > 1:
    db_name = sys.argv[1]
    conn = Connection()
    db = conn[db_name]
    coll = db['video']
    grab_daily_meta(coll)


else:
    print 'No arguments passed'
    sys.exit()
                           
#grab_daily_meta()
#grab_daily_events(1268121600)
