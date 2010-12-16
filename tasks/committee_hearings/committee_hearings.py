from BeautifulSoup import BeautifulStoneSoup, BeautifulSoup
import feedparser
import re
import urllib2
import datetime, time


def run(db):
    senate_count = senate_hearings(db)
    house_count = house_hearings(db)

    db.success("Updated or created %s House and %s Senate committee hearings" % (house_count, senate_count))


def senate_hearings(db):
    chamber = "senate"
    try:
      page = urllib2.urlopen("http://www.senate.gov/general/committee_schedules/hearings.xml")
    except:
      db.report("Couldn't load Senate hearings feed, can't proceed")
      
    else:
      soup = BeautifulStoneSoup(page)
      meetings = soup.findAll('meeting')
      
      count = 0
      
      for meeting in meetings:
          committee_id = meeting.cmte_code.contents[0].strip()
          committee_id = re.sub("(\d+)$", "", committee_id)
          
          date_string = meeting.date.contents[0].strip()
          occurs_at = datetime.datetime(*time.strptime(date_string, "%d-%b-%Y %I:%M %p")[0:6])
          legislative_day = occurs_at.strftime("%Y-%m-%d")
          
          try:
            time_str = meeting.time.contents[0].strip()
            time_of_day = time.strptime(time_str, "%I:%M %p")
            time_of_day = datetime.datetime(*time_of_day[0:6])
            time_of_day = time_of_day.strftime("%I:%M%p")
          except ValueError:
            time_of_day = None
          
          document = None
          if meeting.document:
            document = meeting.document.contents[0].strip()
              
          room = meeting.room.contents[0].strip()
          description = meeting.matter.contents[0].strip().replace('\n', '')
          
          db.get_or_create('committee_hearings', {
              'chamber': 'senate', 
              'committee_id': committee_id, 
              'legislative_day': legislative_day
            }, {
              'room': room, 
              'description': description, 
              'occurs_at': occurs_at, 
              'document_id': document, 
              'time_of_day': time_of_day
            })
          
          count += 1
      
      return count

def house_hearings(db):
    today = datetime.date.today()
  
    doc = feedparser.parse("http://www.govtrack.us/users/events-rss2.xpd?monitors=misc:allcommittee")
    items = doc['items']
    
    count = 0
    for item in items:
        title_str = item.title.replace('Committee Meeting Notice: ', '')
        chamber = title_str.partition(' ')[0]
        
        if chamber == "House":
            
            committee_id = None
            match = re.compile("xpd\?id=([A-Z]+)$").search(item.link)
            if match:
              committee_id = match.group(1)
            
            occurs_at = None
            if hasattr(item, 'pubDate_parsed'):
                occurs_at = datetime.datetime(*item.pubDate_parsed[:7])
            
            
            soup = BeautifulSoup(item.description)
            full_description = soup.findAll('p')[0].contents[0]
            
            occurs_at = None
            legislative_day = None
            time_of_day = None
            description = full_description
            
            match = re.compile("^([^\.]+)\.").search(full_description)
            if match:
                date_str = match.group(1)
                timestamp = time.strptime(date_str, "%a, %b %d, %Y %I:%M %p")
                occurs_at = datetime.datetime(*timestamp[:7])
                legislative_day = occurs_at.strftime("%Y-%m-%d")
                time_of_day = occurs_at.strftime("%I:%M %p")
                description = full_description.replace("%s. " % date_str, "")
            else:
                db.warning("Couldn't parse date from committee description (%s), possible problem with parser" % date_str)
                
            #description = p.split(' -- ')[0].strip()
            #date_str = p.split(' -- ')[1].replace(' at ', ' ').replace('a.m', 'AM').replace('p.m.', 'PM').replace('.', '').strip()
            
            db.get_or_create('committee_hearings', {
                'chamber': 'house', 
                'committee_id': committee_id, 
                'occurs_at': occurs_at,
              }, {
                'description': description, 
                'legislative_day': legislative_day, 
                'time_of_day': time_of_day
              })
            
            count += 1
        
        elif chamber != "Senate":
            db.warning("Found committee chamber (%s) not House or Senate, possible problem with parser" % chamber)
    
    return count