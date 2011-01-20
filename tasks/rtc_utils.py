import re


def current_session(year=None):
  if not year:
    year = datetime.datetime.now().year
  return ((year + 1) / 2) - 894
  


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
    
def extract_bills(text, session):
    text= text.upper()
    p = re.compile('S\.?\s?CON\.?\s?RES\.?\s?\d{1,5}|H\.?\s?CON\s?RES\.?\s?\d{1,5}|S\.?\s?J\.?\s?RES\.?\s\d{1,5}|H\.?\s?J\.?\s?RES\.?\s\d{1,5}|S\.?\s?RES\.?\s?\d{1,5}|H\.?\s?RES\.?\s?\d{1,5}|H\.?\s?\R\.?\s?\d{1,5}|S\.?\s?\d{1,5}')
    needle_list = p.findall(text)
    for i in range(len(needle_list)):
        needle_list[i] = bill_id_for(needle_list[i], session)
    return remove_dupes(needle_list)

def extract_legislators(text, db):
    legislator_names = []
    bioguide_ids = []
    
    name_re = re.compile('((M(rs|s|r)\.){1}\s((\s?[A-Z]{1}[A-Za-z-]+){0,2})(,\s?([A-Z]{1}[A-Za-z-]+))?((\sof\s([A-Z]{2}))|(\s?\(([A-Z]{2})\)))?)')
  
    name_matches = re.findall(name_re, text)
    if name_matches:
        for n in name_matches:
            raw_name = n[0]
            query = {"chamber": "house"}
            
            if n[1]:
                if n[1] == "Mr." : query["gender"] = 'M'
                else: query['gender'] = 'F'
            if n[3]:
                query["last_name"] = n[3]
            if n[6]:
                query["first_name"] = n[6]
            if n[9]:
                query["state"] = n[9]
            elif n[11]:
                query["state"] = n[11]
                
            possibles = db['legislators'].find(query)
            
            if possibles.count() > 0:
                if text not in legislator_names:
                    legislator_names.append(raw_name)
                    
            for p in possibles:
                if p['bioguide_id'] not in bioguide_ids:
                    bioguide_ids.append(p['bioguide_id'])
    
    return (legislator_names, bioguide_ids)










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