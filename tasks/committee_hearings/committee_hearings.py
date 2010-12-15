from BeautifulSoup import BeautifulStoneSoup, BeautifulSoup
import feedparser
import re

import urllib2
import datetime, time
from pymongo import Connection
import sys
import traceback


def file_report(db, status, message, source):
    db['reports'].insert({'status': status, 'read': False, 'message':message, 'source': source, 'created_at': datetime.datetime.now()})
    
def get_or_create(db, collection, criteria, info):
    document = None
    documents = db[collection].find(criteria)
    
    if documents.count() > 0:
      document = documents[0]
    else:
      document = criteria
      document['created_at'] = datetime.datetime.now()
      
    document['updated_at'] = datetime.datetime.now()
    document.update(info)
    
    db[collection].save(document)
    
if len(sys.argv) > 2:
    db_host = sys.argv[1]
    db_name = sys.argv[2]
    conn = Connection(host=db_host)
    db = conn[db_name]
    
    def senate_hearings():
        chamber = "senate"
        try:
          page = urllib2.urlopen("http://www.senate.gov/general/committee_schedules/hearings.xml")
        except:
          file_report(db, "WARNING", "Couldn't load Senate hearings feed, can't proceed", "CommitteeHearings")
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
              
              get_or_create(db, 'committee_hearings', {
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
    
    def house_hearings():
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
                    file_report(db, "WARNING", "Couldn't parse date from committee description (%s), possible problem with parser" % date_str, "CommitteeHearings")
                    
                #description = p.split(' -- ')[0].strip()
                #date_str = p.split(' -- ')[1].replace(' at ', ' ').replace('a.m', 'AM').replace('p.m.', 'PM').replace('.', '').strip()
                
                get_or_create(db, 'committee_hearings', {
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
                file_report(db, "WARNING", "Found committee chamber (%s) not House or Senate, possible problem with parser" % chamber, "CommitteeHearings")
        
        return count
        
        
    try:
        total_count = 0
        total_count += senate_hearings()
        total_count += house_hearings()
    
    except Exception as e:
        print e
        exc_type, exc_value, exc_traceback = sys.exc_info()
        file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "CommitteeHearings")
    
    else:
        file_report(db, "SUCCESS", "Updated or created %s committee hearings" % total_count, "CommitteeHearings")