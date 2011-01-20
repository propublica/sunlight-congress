import re


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