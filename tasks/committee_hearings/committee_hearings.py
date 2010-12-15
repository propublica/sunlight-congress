from BeautifulSoup import BeautifulStoneSoup
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
              
              get_or_create(db, 'committee_hearings', {'chamber': 'senate', 'committee_id': committee_id, 'legislative_day': legislative_day}, {'room': room, 'description': description, 'occurs_at': occurs_at, 'document': document, 'time_of_day': time_of_day})
              
              count += 1
          
          return count

    
    try:
        total_count = 0
        total_count += senate_hearings()
    
    except Exception as e:
        print e
        exc_type, exc_value, exc_traceback = sys.exc_info()
        file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "CommitteeHearings")
    
    else:
        file_report(db, "SUCCESS", "Updated or created %s committee hearings" % total_count, "CommitteeHearings")