from BeautifulSoup import BeautifulStoneSoup
import re
import urllib2
import datetime, time
import rtc_utils
import HTMLParser


def run(db, es, options = {}):
    senate_count = senate_hearings(db)
    db.success("Updated or created %s Senate committee hearings" % senate_count)


def senate_hearings(db):
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
            
          committee_id = meeting.cmte_code.contents[0].strip()
          committee_id = re.sub("(\d+)$", "", committee_id)
          
          # resolve discrepancies between Sunlight and the Senate
          committee_id = rtc_utils.committee_id_for(committee_id)
          if not committee_id:
            continue
          
          committee = committee_for(db, committee_id)

          # Don't warn if it's a bill-specific conference committee
          if not committee and committee_id != "JCC":
            db.warning("Couldn't locate committee by committee_id \"%s\" while parsing Senate committee hearings" % committee_id, {'committee_id': committee_id})
          
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
          
          hearing = db.get_or_initialize('committee_hearings', {
              'chamber': 'senate', 
              'committee_id': committee_id, 
              'occurs_at': occurs_at
          })
          
          hearing.update({
            'room': room, 
            'description': description, 
            'legislative_day': legislative_day,
            'time_of_day': time_of_day,
            'session': session
          })
          
          if committee:
            hearing['committee'] = committee
          
          db['committee_hearings'].save(hearing)
          
          count += 1
      
      return count

def house_hearings(db):
    today = datetime.date.today()
    session = rtc_utils.current_session(today.year)
    
    try:
      url = "http://www.govtrack.us/data/us/%s/committeeschedule.xml" % session
      page = urllib2.urlopen(url).read()
    except:
      # not expected for GovTrack's server to be flakey, thus warning and not note
      db.warning("Couldn't load GovTrack house hearings feed, can't proceed")
      
    else:
      soup = BeautifulStoneSoup(page)
      
      count = 0
      
      problems = []
      
      meetings = soup.findAll('meeting')
      for meeting in meetings:
          if meeting['where'] != 'h':
              continue
          
          committee_id = rtc_utils.committee_id_for(meeting['committee-id'], meeting['committee'])
          if not committee_id:
              problems.append("Blank committee ID for %s" % meeting['committee'])
              continue
              
          committee = committee_for(db, committee_id)
          if not committee:
              problems.append("Couldn't locate committee by committee_id (%s) while parsing House committee hearings" % committee_id)
          
          
          bill_ids = []
          bills = meeting.findAll('bill')
          for bill in bills:
              bill_type = rtc_utils.bill_type_for(bill['type'])
              bill_ids.append("%s%s-%s" % (bill_type, bill['number'], bill['session']))
          
          
          occurs_at = rtc_utils.parse_iso8601(meeting['datetime'])
          
          legislative_day = rtc_utils.in_est(occurs_at).strftime("%Y-%m-%d")
          time_of_day = rtc_utils.in_est(occurs_at).strftime("%I:%M %p")
          description = meeting.find('subject').text
          
          hearing = db.get_or_initialize('committee_hearings', {
              'chamber': 'house', 
              'committee_id': committee_id, 
              'occurs_at': occurs_at
          })
          
          hearing.update({
              'description': description, 
              'legislative_day': legislative_day,
              'time_of_day': time_of_day,
              'session': session,
              'bill_ids': bill_ids
          })
          
          if committee:
              hearing['committee'] = committee
              
          db['committee_hearings'].save(hearing)
          
          count += 1
      
      if len(problems) > 0:
        db.warning("%i problems while going through House committee hearings" % len(problems), {'messages': problems})
        
      return count

def committee_for(db, committee_id):
  committee = db['committees'].find_one({'committee_id': committee_id}, fields=["committee_id", "name", "chamber"])
  if committee:
    del committee['_id']
  return committee