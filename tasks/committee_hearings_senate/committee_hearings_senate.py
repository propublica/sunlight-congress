from BeautifulSoup import BeautifulStoneSoup
import re
import urllib2
import datetime, time
import rtc_utils
import HTMLParser


def run(db, es, options = {}):
    try:
      page = urllib2.urlopen("http://www.senate.gov/general/committee_schedules/hearings.xml")
    except:
      db.note("Couldn't load Senate hearings feed, can't proceed")
      
    else:
      soup = BeautifulStoneSoup(page)
      meetings = soup.findAll('meeting')
      parser = HTMLParser.HTMLParser()
      
      count = 0
      
      for meeting in meetings:
          if re.search("^No.*?scheduled\.?$", meeting.matter.contents[0]):
            continue
            
          full_id = meeting.cmte_code.contents[0].strip()
          committee_id, subcommittee_id = re.search("^([A-Z]+)(\d+)$", full_id).groups()
          if subcommittee_id == "00": 
            subcommittee_id = None
          else:
            subcommittee_id = full_id
          
          committee = committee_for(db, committee_id)
          

          # Don't warn if it's a bill-specific conference committee
          if not committee and committee_id != "JCC":
            db.warning("Couldn't locate committee by committee_id %s" % committee_id, {'committee_id': committee_id})
          
          committee_url = meeting.committee['url']

          date_string = meeting.date.contents[0].strip()
          occurs_at = datetime.datetime(*time.strptime(date_string, "%d-%b-%Y %I:%M %p")[0:6], tzinfo=rtc_utils.EST())
          legislative_day = occurs_at.strftime("%Y-%m-%d")
          session = rtc_utils.current_session(occurs_at.year)
          
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

          # content is double-escaped, e.g. &amp;quot;
          description = parser.unescape(parser.unescape(description))

          bill_ids = rtc_utils.extract_bills(description, session)
          

          documents = db['committee_hearings'].find({
            'chamber': 'senate', 
            'committee_id': committee_id, 
              
            "$or": [{
              'occurs_at': occurs_at
              },{
              'description': description
            }]
          })

          hearing = None
          if documents.count() > 0:
            hearing = documents[0]
          else:
            hearing = {
              'chamber': 'senate', 
              'committee_id': committee_id
            }

            hearing['created_at'] = datetime.datetime.now()
          
          if subcommittee_id:
            hearing['subcommittee_id'] = subcommittee_id
          hearing['updated_at'] = datetime.datetime.now()
          
          hearing.update({
            'bill_ids': bill_ids,
            'occurs_at': occurs_at,
            'room': room, 
            'description': description, 
            'legislative_day': legislative_day,
            'time_of_day': time_of_day,
            'session': session,
            'committee_url': committee_url,
            'dc': True
          })
          
          if committee:
            hearing['committee'] = committee
          
          db['committee_hearings'].save(hearing)
          
          count += 1
      
      db.success("Updated or created %s Senate committee hearings" % count)

def committee_for(db, committee_id):
  committee = db['committees'].find_one({'committee_id': committee_id}, fields=["committee_id", "name", "chamber"])
  if committee:
    del committee['_id']
  return committee