from BeautifulSoup import BeautifulSoup
import urllib2
import datetime, time
import re


def run(db, options = {}):    
    if options['day']:
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
        
        # name for the section if one exists
        
        section = header.parent.findAll('tr')[-1]
        items = section.findChild("td").findChildren("p")
        
        if not items:
          continue
        
        legislative_day = day.strftime("%Y-%m-%d")
        
        
        current_events = []
        current_name = None
        current_time = None
        
        # go over each p tag, find the substantive ones, record it as an event
        for item in items:
          str = item.text.strip()
          
          # first, check if it's a name and time line
          new_name, new_time = name_and_time(str, day)
          if new_name and new_time:
            # if so, save any events we've been accruing, if there are any
            if current_events:
              save_update(db, current_time, legislative_day, current_events)
            
            # then clear the accruing events and start a new one with the new name and timestamp
            current_events = []
            current_name = new_name
            current_time = new_time
            continue
          
          # otherwise, if there's content, add it to the accruing events for this person and this time
          elif current_name and current_time:
            str = re.sub("^o?(?:&[^;]+;)*", "", str) # eliminate all starting special chars
            str = re.sub("^o?SUMMARY", "", str) # not sure why the o and the SUMMARY appear
            if str:
              current_events.append("%s: %s" % (current_name, decode_htmlentities(str)))
        
        # if there were any left when we're all done, save them
        if current_events:
          save_update(db, current_time, legislative_day, current_events)
        
        
        count += 1
        
   
    db.success("Updated or created %s floor updates for the Senate" % count)


def save_update(db, timestamp, legislative_day, events):
  event = db.get_or_initialize("floor_updates", {
    'timestamp': timestamp, 
    'chamber': 'senate'
  })
  
  event['events'] = [events]
  event['legislative_day'] = legislative_day
  
  db['floor_updates'].save(event)

# example: "&nbsp;Senator Durbin:(2:20 PM)"
def name_and_time(text, day):
  matches = re.search("(Senator [^:]+):\((\d+:\d+ (?:AM|PM))", text)
  if matches:
    name = matches.groups()[0]
    time_str = matches.groups()[1]
  
    # timestamp
    time_of_day = time.strptime(time_str, "%I:%M %p")
    
    # I have observed clashing timestamps once, but in that case the Senate had made a mistake and the
    # entries were duplicates of each other.
    timestamp = datetime.datetime(day.year, day.month, day.day, time_of_day.tm_hour, time_of_day.tm_min)
  
    return (name, timestamp)
    
  else:
    return (None, None)


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