from BeautifulSoup import BeautifulSoup
import urllib2
import datetime, time
import re
import rtc_utils


def run(db, options = {}):
    try:
        page = urllib2.urlopen("http://clerk.house.gov/floorsummary/floor.html").read()
        
    except:
        db.note("Couldn't load floor updates URL, can't go on")
        exit()
    
    # strip out bill link metadata and surrounding tags to make splitting events easier
    page = re.compile("<dt><b>\s*<a[^>]+>([^<]+)</a>:</b><dd>", flags=re.I).sub("\\1: ", page)
    page = re.compile("<A HREF=\"http://clerk.house.gov/cgi-bin/vote[^>]+>([^<]+)</a>", flags=re.I).sub("\\1", page)
    page = re.compile("<a class=\"billInfo\"[^>]+>([^<]+)</a>", flags=re.I).sub("\\1", page)
    
    soup = BeautifulSoup(page)
    
    date_objs = soup.findAll(text=re.compile('LEGISLATIVE DAY OF'))
    if not date_objs:
        db.note("Couldn't find date while parsing the House floor updates, bailing out, html attached", {"html": page})
        exit()
        
    date_field = date_objs[0].strip()
    
    day_of_pieces = time.strptime(date_field.replace('LEGISLATIVE DAY OF ', ''), "%B %d, %Y")
    day_of_string = time.strftime("%m/%d/%Y", day_of_pieces)
    
    year = day_of_pieces[0]
    session = rtc_utils.current_session(year)
    
    count = 0
    
    rows = soup.findAll('dt')
    for row in rows:
        if row.b.contents:
            time_string = row.b.contents[0]
            t = re.compile("(\d+:\d{2}\s+(A|P)\.M\.)")
            m = t.findall(time_string)
            
            if m:
                
                time_string = rtc_utils.remove_extra_spaces(m[0][0].replace('.', ''))
                time_string = "%s %s" % (day_of_string, time_string)
                
                event_time_components = time.strptime(time_string, "%m/%d/%Y %I:%M %p")
                event_time = datetime.datetime(*event_time_components[0:5])
                legislative_day = time.strftime("%Y-%m-%d", event_time_components)
                
                events = []
                maybe_events = row.findNextSibling().findAll(text=True)
                for event in maybe_events:
                    event = rtc_utils.remove_extra_spaces(event).strip()
                    if event:
                        events.append(event)
                
                # put in chronological order
                events.reverse()
                
                all_events = "\n".join(events)
                
                event = db.get_or_initialize("floor_updates", {
                  'timestamp': event_time,
                  'chamber': 'house'
                })
                
                event['events'] = events
                event['legislative_day'] = legislative_day
                event['bill_ids'] = rtc_utils.extract_bills(all_events, session)
                event['roll_ids'] = rtc_utils.extract_rolls(all_events, 'house', year)
                event['legislator_ids'] = rtc_utils.extract_legislators(all_events, 'house', db)[1]
                
                db['floor_updates'].save(event)
                
                count += 1
   
    db.success("Updated or created %s floor updates for the House" % count)