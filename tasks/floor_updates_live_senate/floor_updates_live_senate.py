from BeautifulSoup import BeautifulSoup, SoupStrainer
import urllib2

import datetime, time
from pymongo import Connection
import sys
import traceback

if len(sys.argv) > 2:
    db_host = sys.argv[1]
    db_name = sys.argv[2]
    conn = Connection(host=db_host)
    db = conn[db_name]
    
    def file_report(db, status, message, source):
        db['reports'].insert({'status': status, 'read': False, 'message':message, 'source': source, 'created_at': datetime.datetime.now()})

    def get_or_create_event(db, details):
        event = {'timestamp': details['timestamp'], 'chamber': details['chamber']}
        objs = db['floor_updates'].find(event)
        
        if objs.count() > 0:
            return objs[0]
        else:
            return event
    
    try:
        page = urllib2.urlopen("http://republican.senate.gov/public/index.cfm?FuseAction=FloorUpdates.Home").read()
        
    except:
        file_report(db, "WARNING", "Couldn't load floor updates URL, can't go on", "FloorUpdatesLiveSenate")
        exit()
    
    
    count = 0
    
    try:
        soup = BeautifulSoup(page)
        rows = soup.findAll('div', {'class': 'EventCalendarEvent'})
        
        for row in rows:
            time_str = row.strong.contents[0]
            date_str = row.a['href'].replace('index.cfm?FuseAction=FloorUpdates.Home&Date=', '').split('#')[0]
            datetime_str = "%s %s" % (date_str, time_str)
            
            occurred_at = time.strptime(datetime_str, "%d-%b-%y %I:%M %p")
            timestamp = datetime.datetime(*occurred_at[0:6])
            legislative_day = time.strftime("%Y-%m-%d", occurred_at)
            
            events = row.a.contents[0].replace('Floor -- ', '')
            
            event = get_or_create_event(db, {'timestamp':timestamp, 'chamber': 'senate'})
            event['events'] = [events]
            event['legislative_day'] = legislative_day
            
            db['floor_updates'].save(event)
            
            count += 1
        
    except Exception as e:
        print e
        exc_type, exc_value, exc_traceback = sys.exc_info()
        file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "FloorUpdatesLiveSenate")
    
    else:
        file_report(db, "SUCCESS", "Updated or created %s floor updates the Senate" % count, "FloorUpdatesLiveSenate")