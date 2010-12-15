import feedparser
import urllib2
from BeautifulSoup import BeautifulSoup, SoupStrainer
import re

import datetime, time
from pymongo import Connection
import sys
import traceback

def file_report(db, status, message, source):
    db['reports'].insert({'status': status, 'read': False, 'message':message, 'source': source, 'created_at': datetime.datetime.now()})

if len(sys.argv) > 2:
    db_host = sys.argv[1]
    db_name = sys.argv[2]
    conn = Connection(host=db_host)
    db = conn[db_name]
    
    PREFIX = 'http://majoritywhip.house.gov/'

    total_count = 0

    def get_or_create_notice(chamber, posted_at, party, notice_type):
        notice = {'chamber': chamber, 'posted_at': posted_at, 'party': party, 'notice_type': notice_type}
        
        objs = db['whip_notices'].find(notice)
        if objs.count() > 0:
          notice = objs[0]
        else:
          notice['created_at'] = datetime.datetime.now()
          
        notice['updated_at'] = datetime.datetime.now()
        return notice

    def house_dem(notice_type, source):
        count = 0
        doc = feedparser.parse(source)
        items = doc['items']
        for item in items:
            url = '%s%s' % (PREFIX, item.link.replace('&amp;', '&').replace(PREFIX, ''))
            
            posted_at = None
            if hasattr(item, 'updated_parsed'):
                posted_at = datetime.datetime(*item.updated_parsed[:6])
          
            notice = get_or_create_notice('house', posted_at, 'D', notice_type)
            notice['url'] = url
            db['whip_notices'].save(notice)
            
            count += 1
        
        return count
    
    
    def single_digify(date_str):
        m_str = date_str.split('-')[0].lstrip('0')
        d_str = date_str.split('-')[1].lstrip('0')
        y_str = date_str.split('-')[2]
        return "%s-%s-%s" % (m_str, d_str, y_str)     
    
    #handy string cleaning functions found at http://love-python.blogspot.com/2008/07/strip-html-tags-using-python.html
    def remove_extra_spaces(data):
        p = re.compile(r'\s+')
        return p.sub(' ', data)

    def remove_html_tags(data):
        p = re.compile(r'<.*?>')
        return p.sub('', data)

    def house_rep():
      try:
          page = urllib2.urlopen("http://republicanwhip.house.gov/floor/")
      except:
          file_report(db, 'WARNING', "Couldn't load Republican Whip house floor page, skipping", "WhipNotices")
      else:
          soup = BeautifulSoup(page)
          titles = soup.findAll('span', {'class':'h2a'})
          
          daily_title = 'The Whipping Post - '
          weekly_title = 'The Whip Notice - Week of '
          
          count = 0
          
          for title in titles:
              daily_re = re.compile(daily_title)
              weekly_re = re.compile(weekly_title)
              title_str = title.contents[0].strip()
              
              if weekly_re.match(title_str):
                  weekly_date_str = title_str.replace(weekly_title, '').strip()
                  weekly_date = datetime.datetime(*time.strptime(weekly_date_str, "%m/%d/%y")[0:6])
                  weekly_url = "http://republicanwhip.house.gov/floor/%s.pdf" % single_digify(weekly_date.strftime("%m-%d-%y"))
                  
                  notice = get_or_create_notice("house", weekly_date, "R", "weekly")
                  notice['url'] = weekly_url
                  db['whip_notices'].save(notice)
                  count += 1
              
              # Daily PDFs appear to have been removed
              
              #elif daily_re.match(title_str):
                  #daily_date_str = title_str.replace(daily_title, '').strip()
                  #daily_date = datetime.datetime(*time.strptime(daily_date_str, "%m/%d/%y")[0:6])
                  #daily_url = "http://republicanwhip.house.gov/floor/%s.pdf" % single_digify(daily_date.strftime("%m-%d-%y"))
                  
                  #notice = get_or_create_notice("house", daily_date, "R", "daily")
                  #notice ['url'] = daily_url
                  #db['whip_notices'].save(notice)
              
          return count

    
    try:
        total_count += house_dem('daily', "%s?a=RSS.Feed&Type=TheDailyWhipline" % PREFIX)
        total_count += house_dem('weekly', "%s?a=RSS.Feed&Type=TheDailyWhipPack" % PREFIX)
        total_count += house_rep()
    
    except Exception as e:
        print e
        exc_type, exc_value, exc_traceback = sys.exc_info()
        file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "WhipNotices")
    
    else:
        file_report(db, "SUCCESS", "Updated or created %s whip notices" % total_count, "WhipNotices")