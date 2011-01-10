#main driver for daily scrape.  scrapes daily meta information for a house proceeding and saves to mongo if record doesn't already exist

from BeautifulSoup import BeautifulSoup, SoupStrainer
from urlparse import urlparse
import datetime, time
import urllib2
import re
import feedparser

PARSING_ERRORS = []

def run(db):
    grab_daily_meta(db)
    #pull_wmv_rss(db['videos'])
    if PARSING_ERRORS:
        db.note("Errors while parsing timestamps", {errors: PARSING_ERRORS})

def get_mms_url(clip_id):
    clip_xml = urllib2.urlopen("http://houselive.gov/asx.php?clip_id=%s&view_id=2&debug=1" % clip_id).read()
    mms_url = re.search("(<REF HREF=\")([^\"]+)", clip_xml).groups()[1]
    return mms_url 
    
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
    print "got page"
    
    count = 0
    
    for row in rows:
        try:
            cols = row.findAll('td')
            if len(cols) > 0:
                unix_time = cols[0].span.string
                this_date = datetime.datetime.fromtimestamp(float(unix_time))
                date_key = datetime.datetime(this_date.year, this_date.month, this_date.day, 12, 0, 0)
                timestamp_key = int(time.mktime(date_key.timetuple()))
                
                video_id = 'house-' + str(timestamp_key)
                fd = db.get_or_initialize('videos', {'video_id': video_id})
                
                legislative_day = datetime.datetime.strptime(cols[0].contents[1] + " 12:00", '%B %d, %Y %H:%M')
                fd['legislative_day'] = legislative_day.strftime("%Y-%m-%d")
                fd['created_at'] = add_date.strftime("%Y-%m-%dT%H:%MZ")
                duration_hours = cols[1].contents[0]
                duration_minutes = cols[1].contents[2].replace('&nbsp;', '')
                fd['duration'] = convert_duration(duration_hours, duration_minutes)
                fd['clip_id'] = locate_clip_id(cols[3].contents[2]['href'])
                fd['chamber'] = 'house'
                fd['pubdate'] = date_key.strftime("%Y-%m-%dT%H:%Mz")
                mms_url = get_mms_url(fd['clip_id'])
                try:
                    if fd.has_key('clip_urls'):
                        fd['clip_urls']['mp3'] = cols[4].a['href']
                        fd['clip_urls']['mp4'] = cols[4].a['href'].replace('.mp3', '.mp4')
                        fd['clip_urls']['mms'] = mms_url
                    else:
                        fd['clip_urls'] = {
                                'mp3':  cols[4].a['href'],
                                'mp4':  cols[4].a['href'].replace('.mp3', '.mp4'),
                                'mms': mms_url
                                #'wmv':  cols[4].a['href'].replace('.mp3', '.wmv'),
                                }
                except Exception:
                    if mms_url:
                        if fd.has_key('clip_urls'):
                            fd['clip_urls']['mms'] = mms_url

                        else:
                            fd['clip_urls'] = { 'mms':mms_url }

                fd['clips'], fd['bills'], fd['bioguide_ids'], fd['legislator_names'] = grab_daily_events(fd, db)
                print fd['clip_urls']
                db['videos'].save(fd)
                
                count += 1
        except Exception as e:
#            print "exception! %s " % e
            db.warning(e)
            continue
    
    db.success("Updated or created %s legislative days for House video" % count)
                            
def grab_daily_events(full_video, db):
    
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
    
    def add_to_video_array(floor_event, key, vid_array):
            if floor_event.has_key(key): 
                for k in fe[key]:
                    if k not in vid_array:
                        vid_array.append(k)
            return vid_array

    def add_event(obj, text):
        text = text.strip()
        if obj.has_key('events'):
            obj['events'].append(text)
        else:
            obj['events'] = [text,]
        return obj
    
    def parse_group(group, clip, fu, db):
        global PARSING_ERRORS
        bills = []
        legislator_names = []
        bioguide_ids = []
        congress =  ((clip['time'].year + 1) / 2 ) - 894
        bill_re = re.compile('((S\.|H\.)(\s?J\.|\s?R\.|\s?Con\.| ?)(\s?Res\.)*\s?\d+)')
        name_re = re.compile('((M(rs|s|r)\.){1}\s((\s?[A-Z]{1}[A-Za-z-]+){0,2})(,\s?([A-Z]{1}[A-Za-z-]+))?((\sof\s([A-Z]{2}))|(\s?\(([A-Z]{2})\)))?)')

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
                if text:
                    clip = add_event(clip, text)
                    fu = add_event(fu, text)
                    
                    #find bill text
                    bill_matches = re.findall(bill_re, text)
                    if bill_matches:
                        for b in bill_matches:
                            bill_text = "%s-%s" % (b[0].lower().replace(" ", '').replace('.', '').replace("con", "c"), congress)
                            if bill_text not in bills:
                                bills.append(bill_text)
                    #find legislator names
                    name_matches = re.findall(name_re, text)
                    if name_matches:
                        for n in name_matches:
                            raw_name = n[0]
                            query = {"chamber": "house"}
                            if n[1]:
                                if n[1] == "Mr." : query["gender"] = 'M'
                                else: query['gender'] = 'F'
                            if n[3]:
                                query["last_name"] = n[3]
                            if n[6]:
                                query["first_name"] = n[6]
                            if n[9]:
                                query["state"] = n[9]
                            elif n[11]:
                                query["state"] = n[11]
                            possibles = db['legislators'].find(query)
                            if possibles.count() > 0:
                                if text not in legislator_names:
                                    legislator_names.append(raw_name)
                            for p in possibles:
                                if p['bioguide_id'] not in bioguide_ids:
                                    bioguide_ids.append(p['bioguide_id'])
                else:
                    PARSING_ERRORS.append((clip['legislative_day'].strftime("%Y-%m-%d"), "Couldn't parse text: %s" % pt.contents))
            if hasattr(pt.nextSibling, 'name'):
                pt = pt.nextSibling
            else:
                break
        if bills:
            clip['bills'] = bills
            fu['bills'] = bills
        if legislator_names:
            clip['legislator_names'] = legislator_names
            fu['legislator_names'] = legislator_names
        if bioguide_ids:
            clip['bioguide_ids'] = bioguide_ids
            fu['bioguide_ids'] = bioguide_ids

        return (clip, fu)

    url = "http://houselive.gov/MinutesViewer.php?view_id=2&clip_id=%s&event_id=&publish_id=&is_archiving=0&embedded=1&camera_id=" % full_video['clip_id']
    page = urllib2.urlopen(url).read()
    add_date = datetime.datetime.now()
    soup = BeautifulSoup(page.replace("<p />", "</p><p>"))
    
    clips = []
    legislator_names = []
    bioguide_ids = []
    bills = []

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
                return (None, None, None, None)

        if am_or_pm == 'AM': #finishing after midnight, record is being read in backwards
            date = datetime.datetime.fromtimestamp(float(full_video['video_id'].replace('house-', ''))) + datetime.timedelta(days=1)
        else:
            date = datetime.datetime.fromtimestamp(float(full_video['video_id'].replace('house-', '')))

        for group in groups:
            if group.nextSibling.nextSibling:
                try:
                    offset = int(group.nextSibling.nextSibling.a['onclick'].replace("top.SetPlayerPosition('0:", "").replace("',null); return false;", ""))
                except Exception:
                    offset = None
                
                timestamp, date, am_or_pm = get_timestamp(group, date, am_or_pm)
                fe = {'offset': offset, 'time': timestamp}
                
                legislative_day = full_video['legislative_day']
                
                
                fu = db.get_or_initialize('floor_updates', {
                  'timestamp': timestamp, 
                  'legislative_day': legislative_day, 
                  'chamber': 'house'
                })
                
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
                    fe, fu = parse_group(group, fe, fu, db)

                    #reverse our lists since they're read in backwards
                    fe['events'].reverse()
                    fu['events'].reverse()
                    db['floor_updates'].save(fu)
          
                    #add unique bills to top level array 
                    bills = add_to_video_array(fe, 'bills', bills)
                    bioguide_ids = add_to_video_array(fe, 'bioguide_ids', bioguide_ids)
                    legislator_names = add_to_video_array(fe, 'legislator_names', legislator_names)

                    clips.append(fe)
                else:
                    continue
            
            else:
                print "finished parsing %s" % full_video['legislative_day']
                #print "\n"
        clips.reverse() #since record is read in backwards
        return (clips, bills, bioguide_ids, legislator_names)
    else:
        PARSING_ERRORS.append((full_video["legislative_day"], "Record empty for %s " % full_video["legislative_day"]))
   
   
#pull wmv file links
def pull_wmv_rss(coll):
    
    parsed = feedparser.parse("http://houselive.gov/ViewPublisherRSS.php?view_id=2")
    for video in parsed.entries:
        try:
            link = video.link
            clip_id = re.findall('(?<=clip_id=)\d+', link)[0]
            
            vid = db.get_or_initialize('videos', {'clip_id': clip_id})
            
            if vid.has_key("timestamp_id"):
                wmv_url= video.enclosures[0]['url']
                if vid.has_key('clip_urls'):
                    vid['clip_urls']['mms'] = wmv_url
                else:
                    vid['clip_urls'] = { 'mms' : wmv_url }

                coll.save(vid) 
        except:
            continue 
