from BeautifulSoup import BeautifulSoup
import urllib2
import datetime, time
import re


def run(db):
    try:
        page = urllib2.urlopen("http://clerk.house.gov/floorsummary/floor.html").read()
        
    except:
        db.warning("Couldn't load floor updates URL, can't go on")
        exit()
    
    
    matches = re.findall("LEGISLATIVE DAY OF ([^\n\<]+)[\n\<", page)
    if len(matches) <= 0:
      db.warning("Couldn't parse out legislative day from page, could be issue with parser")
      exit()
    
    today = datetime.date(*time.strptime(matches[0].strip(), "%B %d, %Y")[:3])
    legislative_day = today.strftime("%Y-%m-%d")
    
    soup = BeautifulSoup(page)
    
    # this is going to be tough!
    
    
    #count = 0
    
    #for row in rows:
        #time_str = row.strong.contents[0]
        #date_str = row.a['href'].replace('index.cfm?FuseAction=FloorUpdates.Home&Date=', '').split('#')[0]
        #datetime_str = "%s %s" % (date_str, time_str)
        
        #occurred_at = time.strptime(datetime_str, "%d-%b-%y %I:%M %p")
        #timestamp = datetime.datetime(*occurred_at[0:6])
        #legislative_day = time.strftime("%Y-%m-%d", occurred_at)
        
        #events = row.a.contents[0].replace('Floor -- ', '')
        
        ## I have observed clashing timestamps once, but in that case the Senate had made a mistake and the
        ## entries were duplicates of each other.
        #event = db.get_or_initialize("floor_updates", {'timestamp': timestamp, 'chamber': 'house'})
        
        #event['events'] = [events]
        #event['legislative_day'] = legislative_day
        
        #db['floor_updates'].save(event)
        
        #count += 1
        
   
    #db.success("Updated or created %s floor updates for the House" % count)