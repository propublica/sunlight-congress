from BeautifulSoup import BeautifulSoup
import urllib2
import datetime, time


def run(db):
    try:
        page = urllib2.urlopen("http://republican.senate.gov/public/index.cfm?FuseAction=FloorUpdates.Home").read()
        
    except:
        db.warning("Couldn't load floor updates URL, can't go on")
        exit()
    
    count = 0
    
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
        
        # I have observed clashing timestamps once, but in that case the Senate had made a mistake and the
        # entries were duplicates of each other.
        event = db.get_or_initialize("floor_updates", {'timestamp': timestamp, 'chamber': 'senate'})
        
        event['events'] = [events]
        event['legislative_day'] = legislative_day
        
        db['floor_updates'].save(event)
        
        count += 1
        
   
    db.success("Updated or created %s floor updates for the Senate" % count)