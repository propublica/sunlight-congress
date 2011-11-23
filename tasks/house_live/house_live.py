import json
import urlparse
import httplib2
from datetime import datetime
import time as timey
from dateutil.parser import parse
import pyes

API_PREFIX = 'http://govflix.com/api/'
PARSING_ERRORS = []

def run(db, options = {}):
    
    get_videos(db, 'houselive.gov')
    #add in senatelive.gov later I guess

    if PARSING_ERRORS:
        db.note("Errors while parsing timestamps", {'errors': PARSING_ERRORS})



def get_markers(db, chamber, vid_id=None):
    api_url = API_PREFIX + chamber + '?type=marker&size=100000'
    markers = query_api(db, api_url)

def try_key(data, key, name, new_data):
    if data.has_key(key):
        new_data[name] = data[key]
        return new_data
    else:
        return new_data

def get_videos(db, chamber):
    api_url = API_PREFIX + chamber + '?type=video&size=100000'
    videos = query_api(db, api_url)
    for vid in videos:
        new_vid = {} 
        v = vid['_source']

        new_vid = try_key(v, 'id', 'clip_id', new_vid)
        new_vid = try_key(v, 'http', 'mp4', new_vid)
        new_vid = try_key(v, 'hls', 'hls', new_vid)
        new_vid = try_key(v, 'rtmp', 'rtmp', new_vid)
        # Left off here - use pyes to query instead of httplib and change to an archive mode and a last 2 vids mode 
        try:
            legislative_day = datetime.strptime(v['name'][v['name'].index('OF')+2:], '%B %d %Y')
        except:
            legislative_day = parse(v['datetime'])
        print legislative_day



def query_api(db, api_url):

    h = httplib2.Http()
    response, text = h.request(api_url)

    if response.get('status') == '200':
        items = json.loads(text)['hits']['hits']
        return items

    else:
        PARSING_ERRORS.append('Got something other than 200 status:' % response.get('status'))


