import feedparser
import urllib2
from BeautifulSoup import BeautifulSoup, SoupStrainer
import re
import datetime, time
import rtc_utils

HOUSE_DEM_URL = 'http://www.democraticwhip.gov/rss/%s/all'
HOUSE_REP_URL = 'http://www.majorityleader.house.gov/floor/%s.html'

def run(db, options = {}):
    total_count = 0
    
    if not ('party' in options and options['party'] == 'r'):
      total_count += house_dem(db, 'daily', HOUSE_DEM_URL % "32")
      total_count += house_dem(db, 'nightly', HOUSE_DEM_URL % "34")
      total_count += house_dem(db, 'weekly', HOUSE_DEM_URL % "31")
    
    if not ('party' in options and options['party'] == 'd'):
      total_count += house_rep(db, 'daily', HOUSE_REP_URL % "daily")
      total_count += house_rep(db, 'weekly', HOUSE_REP_URL % "weekly")
    
    db.success("Updated or created %s whip notices" % total_count)


def house_dem(db, notice_type, source):
    count = 0
    doc = feedparser.parse(source)
    items = doc['items']
    for item in items:
        url = item.link
        
        posted_at = datetime.datetime(*item.updated_parsed[:6])
        session = rtc_utils.current_session(posted_at.year)
      
        for_date = posted_at.strftime("%Y-%m-%d")
      
        notice = db.get_or_initialize("documents", {
          "document_type": "whip_notice",
          "chamber": 'house', 
          'for_date': for_date,
          "party": 'D', 
          "notice_type": notice_type
        })
        
        notice['posted_at'] = posted_at
        notice['url'] = url
        notice['session'] = session
        
        db['documents'].save(notice)
        
        count += 1
    
    return count


def house_rep(db, notice_type, source):
    try:
        page = urllib2.urlopen(source).read()
    except:
        db.warning("Couldn't load Republican House floor page, skipping")
        
    else:
        soup = BeautifulSoup(page)
        content = soup.find("div", id="news_text")
        
        if notice_type == "daily":
          date_format = "%A, %B %d"
          
          # example date_str: WEDNESDAY, JANUARY 26TH
          date_str = content.findAll("b")[0].text.strip()
          # strip off the ordinal
          date_str = re.compile("[A-Z]{2}$", flags=re.I).sub("", date_str)
          time_obj = time.strptime(date_str, date_format)
        else:
          # the publishers seem to alternate randomly and freely between these two formats
          #try:
            date_format = "%B %d"
            date_str = content.findAll("b")[0].text.strip()
            date_str = re.compile("^.*?WEEK OF", flags=re.I).sub("", date_str).strip()
            date_str = re.compile("[a-zA-Z]+$", flags=re.I).sub("", date_str).strip()
            time_obj = time.strptime(date_str, date_format)
          #except ValueError:
            #date_format = "%B %d, %Y"
            #date_str = content.findAll("b")[1].text.strip()
            #date_str = date_str.replace("WEEK OF ", "")
            #time_obj = time.strptime(date_str, date_format)
          
        
        
        # starts with a year of 1900
        
        posted_at = datetime.datetime(time_obj.tm_year, time_obj.tm_mon, time_obj.tm_mday, 12, 0, 0) # noon UTC
        
        # set the time to this year, unless we're clearly at the edge of the year
        now = datetime.datetime.now()
        if now.month == 1 and posted_at.month == 12:
          posted_at = posted_at.replace(now.year - 1)
        else:
          posted_at = posted_at.replace(now.year)
        
        for_date = posted_at.strftime("%Y-%m-%d")
        session = rtc_utils.current_session(posted_at.year)
        
        
        # daily or weekly
        url_results = content.findAll("a", attrs={"href": re.compile("\.pdf$")})
        if not url_results:
          db.warning("Couldn't find URL for PDF of the %s Republican whip notice, can't go on, div attached" % notice_type, {html: content.text})
          return 0
        
        url = url_results[0]['href']
        
        
        notice = db.get_or_initialize("documents", {
          "document_type": "whip_notice",
          'chamber': "house", 
          'for_date': for_date,
          'party': "R", 
          'notice_type': notice_type
        })
        
        notice['posted_at'] = posted_at
        notice['url'] = url
        notice['session'] = session
        
        db['documents'].save(notice)
                
        return 1


def single_digify(date_str):
    m_str = date_str.split('-')[0].lstrip('0')
    d_str = date_str.split('-')[1].lstrip('0')
    y_str = date_str.split('-')[2]
    return "%s-%s-%s" % (m_str, d_str, y_str)