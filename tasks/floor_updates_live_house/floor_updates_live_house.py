from BeautifulSoup import BeautifulSoup
import urllib2
import datetime, time
import re
import rtc_utils


def run(db, options = {}):
    url = "http://clerk.house.gov/floorsummary/floor.html"
    
    if options.has_key('day'):
      day = datetime.datetime.strptime(options['day'], "%Y-%m-%d")
      url = "%s?day=%s" % (url, day.strftime("%Y%m%d"))
      
    try:
        page = urllib2.urlopen(url).read()
        
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
    
    # legislative_day stays constant through all events
    legislative_day = datetime.datetime.strptime(date_field.replace('LEGISLATIVE DAY OF ', ''), "%B %d, %Y")
    year = legislative_day.year
    session = rtc_utils.current_session(year)
    
    # as timestamps tick up and potentially go past midnight to the next day,
    # (and even potentially multiple days, though that is rare)
    # use marks in the sand to figure out what day to advance the timestamp to,
    # even as the "legislative_day" remains the same.
    current_day = legislative_day
    # hold on to the last timestamp - if the next one is ever earlier than the last one,
    # we know it's time to advance the current day
    last_timestamp = None
    
    count = 0
    rows = soup.findAll('dt')
    
    rows.reverse() # go in chronological order, so that we can track how the days advance
    
    for row in rows:
        if row.b.contents:
            time_string = row.b.contents[0]
            t = re.compile("(\d+:\d{2}\s+(A|P)\.M\.)")
            matches = t.findall(time_string)
            
            if matches:
                time_string = rtc_utils.remove_extra_spaces(matches[0][0].replace('.', ''))
                
                # make a test timestamp with this time and the current day
                event_time = datetime.datetime.strptime(time_string, "%I:%M %p")
                event_time = datetime.datetime(current_day.year, current_day.month, current_day.day, event_time.hour, event_time.minute, tzinfo=rtc_utils.EST())
                
                # if the time has ticked over to the next day, advance the current day,
                # and advance the event time accordingly
                if last_timestamp and (event_time < last_timestamp):
                    current_day = current_day.replace(current_day.year, current_day.month, current_day.day + 1)
                    event_time = event_time.replace(current_day.year, current_day.month, current_day.day)
                
                # now that we've settled the real time, store it as the last timestamp
                last_timestamp = event_time
                
                events = []
                maybe_events = row.findNextSibling().findAll(text=True)
                for event in maybe_events:
                    event = rtc_utils.remove_extra_spaces(event).strip()
                    if event:
                        events.append(event)
                
                # put in chronological order
                events.reverse()
                
                event = db.get_or_initialize("floor_updates", {
                  'timestamp': event_time,
                  'chamber': 'house'
                })
                
                event['events'] = events
                event['legislative_day'] = legislative_day.strftime("%Y-%m-%d")
                
                # extract entities
                all_events = "\n".join(events)
                event['bill_ids'] = rtc_utils.extract_bills(all_events, session)
                event['roll_ids'] = rtc_utils.extract_rolls(all_events, 'house', year)
                event['legislator_ids'] = rtc_utils.extract_legislators(all_events, 'house', db)[1]
                
                db['floor_updates'].save(event)
                
                count += 1
   
    db.success("Updated or created %s floor updates for the House" % count)