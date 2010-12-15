import feedparser
import urllib2

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

    def get_or_create_whip_notice(chamber, posted_at, party, notice_type):
      notice = {'chamber': chamber, 'posted_at': posted_at, 'party': party, 'notice_type': notice_type}
      objs = db['whip_notices'].find(notice)
      if objs.count() > 0:
        return objs[0]
      else:
        return notice

    def house_dem_details(notice_type, source):
        count = 0
        doc = feedparser.parse(source)
        items = doc['items']
        for item in items:
            url = '%s%s' % (PREFIX, item.link.replace('&amp;', '&').replace(PREFIX, ''))
            
            posted_at = None
            if hasattr(item, 'updated_parsed'):
                posted_at = datetime.datetime(*item.updated_parsed[:6])
          
            notice = get_or_create_whip_notice('house', posted_at, 'D', notice_type)
            notice['url'] = url
            db['whip_notices'].save(notice)
            
            count += 1
        
        return count
    
    
    try:
        total_count += house_dem_details('daily', "%s?a=RSS.Feed&Type=TheDailyWhipline" % PREFIX)
        total_count += house_dem_details('weekly', "%s?a=RSS.Feed&Type=TheDailyWhipPack" % PREFIX)
    
    except Exception as e:
        print e
        exc_type, exc_value, exc_traceback = sys.exc_info()
        file_report(db, "FAILURE", "Fatal Error - %s - %s" % (e, traceback.extract_tb(exc_traceback)), "WhipNotices")
    
    else:
        file_report(db, "SUCCESS", "Updated or created %s whip notices" % total_count, "WhipNotices")