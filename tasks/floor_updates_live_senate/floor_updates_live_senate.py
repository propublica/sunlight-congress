from BeautifulSoup import BeautifulSoup
import urllib2
import datetime, time
import re
import rtc_utils

def run(db, options = {}): 
    if options.has_key('day'):
      day = datetime.datetime(*time.strptime(options['day'], "%Y-%m-%d")[0:6])
    else:
      day = datetime.datetime.now()
    
    url = "http://republican.senate.gov/public/index.cfm?FuseAction=FloorUpdates.Home&Date=%s" % day.strftime("%d-%b-%y")
  
    try:
        page = urllib2.urlopen(url).read()
        
    except:
        db.note("Couldn't load floor updates URL, can't go on")
        exit()
    
    count = 0
    
    soup = BeautifulSoup(page)
    headers = soup.findAll('h3')
    
    for header in headers:
        fallback_time = section_time(header, day)
        
        section = header.parent.findAll('tr')[-1]
        items = section.findChild("td").findChildren("p")
        
        if not items:
          continue
        
        legislative_day = day.strftime("%Y-%m-%d")
        
        
        current_events = []
        current_name = None
        current_time = None
        current_bioguide_id = None
        
        # go over each p tag, find the substantive ones, record it as an event
        for item in items:
          str = item.text.strip()
          str = re.sub("^o?(?:&[^;]+;)*", "", str) # eliminate all starting special chars
          str = re.sub("^o?SUMMARY", "", str) # not sure why the o and the SUMMARY appear
          
          if str:
            # extraneous weird xml html check, this occurs sometimes
            matches = re.search("</font>([^<]+)$", str)
            if matches:
              str = matches.groups()[0]
            
            # first, check if it's a name and time line
            new_name, new_state, new_time, new_bioguide_id = name_and_time(db, str, day)
            if new_name and new_time:
              # if so, save any events we've been accruing, if there are any
              if current_events:
                save_update(db, current_time, legislative_day, current_events, current_bioguide_id)
              
              # then clear the accruing events and start a new one with the new name and timestamp
              current_events = []
              if new_state:
                current_name = "%s (%s)" % (new_name, new_state)
              else:
                current_name = "%s" % new_name
              current_events.append(current_name)
              current_time = new_time
              current_bioguide_id = new_bioguide_id
              continue
            
            # otherwise, if there's content, add it to the accruing events for this person and this time
            elif current_name and current_time:
              # ignore first-level items (mildly editorialized items)
              #if re.search("mso-list: l\d level1", item['style']):
              
              # ignore quotes
              # if re.search("^&quot;", str):
              
                # print "Ignoring: %s" % str
              # else:
                # current_events.append(decode_htmlentities(str))                
              pass
            else:
              print "No name, no time, no prior recorded name or time: %s" % str
        
        # if there were any left when we're all done, save them
        if current_events:
          save_update(db, current_time, legislative_day, current_events, current_bioguide_id)
        
        
        count += 1
        
   
    db.success("Updated or created %s floor updates for the Senate" % count)


def save_update(db, timestamp, legislative_day, events, bioguide_id):
  event = db.get_or_initialize("floor_updates", {
    'timestamp': timestamp, 
    'chamber': 'senate'
  })
  
  event['bioguide_ids'] = [bioguide_id]
  
  event['events'] = events
  event['legislative_day'] = legislative_day
  
  db['floor_updates'].save(event)

# example: "Senator Durbin:(2:20 PM)"
# example: "Senator Udall-CO:(2:20 PM)"
def name_and_time(db, text, day):
  matches = re.search("^Senator ([^:]+):\((\d+:\d+ (?:AM|PM))", text)
  if matches:
    name = matches.groups()[0]
    time_str = matches.groups()[1]
  
    # if name has a state suffix, split it now
    bioguide_id = None
    state = None
    matches = re.search("(-([A-Z]{2}))$", name)
    if matches:
      name = name.replace(matches.groups()[0], '')
      state = matches.groups()[1]
    
    # match the name regardless of whether we have a state
    bioguide_id = bioguide_id_for(db, name, state)
  
    # timestamp
    time_of_day = time.strptime(time_str, "%I:%M %p")
    
    # I have observed clashing timestamps once, but in that case the Senate had made a mistake and the
    # entries were duplicates of each other.
    timestamp = datetime.datetime(day.year, day.month, day.day, time_of_day.tm_hour, time_of_day.tm_min, tzinfo=rtc_utils.EST())
  
    return (name, state, timestamp, bioguide_id)
    
  else:
    return (None, None, None, None)

# the state should always make the name unambiguous (I hope)
def bioguide_id_for(db, name, state = None):
  query = {'last_name': name}
  if state:
    query['state'] = state
  
  results = db['legislators'].find(query)
  if results.count() > 0:
    return results[0]['bioguide_id']
  else:
    return None

# return timestamp from a whole section of updates
def section_time(header, day):
  date_str = header.nextSibling.nextSibling.strip()
  match = re.search("\d+:\d+ (?:AM|PM)$", date_str)
  
  if match:
    time_str = match.group()
    time_of_day = time.strptime(time_str, "%I:%M %p")
    timestamp = datetime.datetime(day.year, day.month, day.day, time_of_day.tm_hour, time_of_day.tm_min)
    return timestamp

# html entity decoding

from htmlentitydefs import name2codepoint as n2cp

def substitute_entity(match):
  ent = match.group(2)
  if match.group(1) == "#":
    return unichr(int(ent))
  else:
    cp = n2cp.get(ent)

    if cp:
      return unichr(cp)
    else:
      return match.group()

def decode_htmlentities(string):
  entity_re = re.compile("&(#?)(\d{1,5}|\w{1,8});")
  return entity_re.subn(substitute_entity, string)[0]