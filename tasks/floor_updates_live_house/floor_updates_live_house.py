from BeautifulSoup import BeautifulSoup
import urllib2
import datetime, time
import re


def run(db):
    try:
        page = urllib2.urlopen("http://clerk.house.gov/floorsummary/floor.html").read()
        
    except:
        db.note("Couldn't load floor updates URL, can't go on")
        exit()
    
    soup = BeautifulSoup(page)
    
    date_field = soup.findAll(text=re.compile('LEGISLATIVE DAY OF'))[0].strip()
    
    day_of_pieces = time.strptime(date_field.replace('LEGISLATIVE DAY OF ', ''), "%B %d, %Y")
    day_of_string = time.strftime("%m/%d/%Y", day_of_pieces)
    
    year = day_of_pieces[0]
    session = current_session(year)
    
    count = 0
    
    rows = soup.findAll('dt')
    for row in rows:
        if row.b.contents:
            time_string = row.b.contents[0]
            t = re.compile("(\d+:\d{2}\s+(A|P)\.M\.)")
            m = t.findall(time_string)
            if m:
                
                time_string = remove_extra_spaces(m[0][0].replace('.', ''))
                time_string = "%s %s" % (day_of_string, time_string)
                
                event_time_components = time.strptime(time_string, "%m/%d/%Y %I:%M %p")
                event_time = datetime.datetime(*event_time_components[0:5])
                legislative_day = time.strftime("%Y-%m-%d", event_time_components)
                
                description = clean_description(''.join(row.findNextSibling().findAll(text=True)))
                
                event = db.get_or_initialize("floor_updates", {
                  'timestamp': event_time,
                  'chamber': 'house'
                })
                
                event['events'] = [description]
                event['legislative_day'] = legislative_day
                
                event['bill_ids'] = extract_bills(description, session)
                event['roll_ids'] = extract_rolls(description, year)
                
                db['floor_updates'].save(event)
                
                count += 1
   
    db.success("Updated or created %s floor updates for the House" % count)


RTC_MAP = {'hr':'hr', 'hres':'hres', 'hjres':'hjres', 'hconres':'hcres', 's':'s', 'sres':'sres', 'sjres':'sjres', 'sconres':'scres'}
    
def bill_id_for(code, session):
    code = code.replace(' ', '').replace('.', '').lower()
    
    p = re.compile('([a-z]{1,7})(\d{1,4})')
    m = p.match(code)
    
    bill_type = RTC_MAP[m.group(1)]
    number = m.group(2)
    
    return "%s%s-%s" % (bill_type, number, session)
    
def roll_id_for(number, year):
    return "h%s-%s" % (number, year)
    
def extract_rolls(data, year):
    roll_re = re.compile('Roll no. (\d+)')
    needle_list = roll_re.findall(data)
    for i in range(len(needle_list)):
        needle_list[i] = roll_id_for(needle_list[i], year)
    return remove_dupes(needle_list)
    
def extract_bills(haystack, session):
    haystack = haystack.upper()
    p = re.compile('S\.?\s?CON\.?\s?RES\.?\s?\d{1,5}|H\.?\s?CON\s?RES\.?\s?\d{1,5}|S\.?\s?J\.?\s?RES\.?\s\d{1,5}|H\.?\s?J\.?\s?RES\.?\s\d{1,5}|S\.?\s?RES\.?\s?\d{1,5}|H\.?\s?RES\.?\s?\d{1,5}|H\.?\s?\R\.?\s?\d{1,5}|S\.?\s?\d{1,5}')
    needle_list = p.findall(haystack)
    for i in range(len(needle_list)):
        needle_list[i] = bill_id_for(needle_list[i], session)
    return remove_dupes(needle_list)

def current_session(year=None):
  if not year:
    year = datetime.datetime.now().year
  return ((year + 1) / 2) - 894

# string cleaning functions found at:
# http://love-python.blogspot.com/2008/07/strip-html-tags-using-python.html

def remove_extra_spaces(data):
    p = re.compile(r'\s+')
    return p.sub(' ', data)

def remove_html_tags(data):
    p = re.compile(r'<.*?>')
    return p.sub('', data)
    
def clean_description(data):
    data = remove_extra_spaces(remove_html_tags(data.replace("\n", "")))
    return data.strip()


# code from python faq: 
# http://docs.python.org/faq/programming.html#how-do-you-remove-duplicates-from-a-list

def remove_dupes(mylist):
    if mylist:
        mylist.sort()
        last = mylist[-1]
        for i in range(len(mylist)-2, -1, -1):
            if last == mylist[i]:
                del mylist[i]
            else:
                last = mylist[i]
    return mylist