import json
import rtc_utils
import urlparse
import httplib2
from datetime import datetime
import time as timey
from dateutil.parser import parse as dateparse
import pyes

API_PREFIX = 'http://govflix.com/api/'
PARSING_ERRORS = []

def run(db, options = {}):
    
    if options.has_key('archive'):
        get_videos(db, 'houselive.gov', 'house', True )
    else:
        get_videos(db, 'houselive.gov', 'house', False)
    #add in senatelive.gov later I guess

    if PARSING_ERRORS:
        db.note("Errors while parsing timestamps", {'errors': PARSING_ERRORS})


def get_markers(db, client_name, clip_id):
    api_url = API_PREFIX + client_name + '?type=marker&size=100000'
    data = '{"filter": { "term": { "video_id": %s}}, "sort": [{"offset":{"order":"asc"}}]}' % clip_id
    markers = query_api(db, api_url, data)
    clips = []
    for m in markers:
        m_new = m['_source']
        c = {
            'offset': m_new['offset'],
            'events': m_new['name']
        }
        if m != markers[-1]:  #if it's not the last one
            c['duration'] = markers[markers.index(m)+1]['_source']['offset'] - m_new['offset']

        clips.append(c)        
    
    return clips

def try_key(data, key, name, new_data):
    if data.has_key(key):
        new_data[name] = data[key]
        return new_data
    else:
        return new_data

def get_videos(db, client_name, chamber, archive):
    api_url = API_PREFIX + client_name + '?type=video'
    data = '{ "sort": [ {"datetime": {"order": "desc" }} ]  }'
    if archive:
        api_url += '&size=100000'
    else:
        api_url += '&size=2'
    videos = query_api(db, api_url, data)
    for vid in videos:
        
        v = vid['_source']

        try:
            legislative_day = datetime.strptime(v['name'][v['name'].index('OF')+2:], '%B %d %Y')
        except:
            legislative_day = dateparse(v['datetime'])

        video_id = chamber + '-' + str(int(timey.mktime(legislative_day.timetuple())))
        new_vid = db.get_or_initialize('videos', {'video_id': video_id}) 
         
        #initialize arrays and dicts so we don't have to worry about it later
        if not new_vid.has_key('clip_urls'): new_vid['clip_urls'] = {}
        if not new_vid.has_key('bills'): new_vid['bills'] = []
        if not new_vid.has_key('bioguide_ids'): new_vid['bioguide_ids'] = []
        if not new_vid.has_key('legislator_names'): new_vid['legislator_names'] = []

        if not new_vid.has_key('created_at'): new_vid['created_at'] = datetime.now() 
        new_vid['updated_at'] = datetime.now()
        #video id, clips array, legislators array, bills array
        
        new_vid = try_key(v, 'id', 'clip_id', new_vid)
        new_vid = try_key(v, 'duration', 'duration', new_vid)
        new_vid = try_key(v, 'datetime', 'pubdate', new_vid)
        new_vid['clip_urls'] = try_key(v, 'http', 'mp4', new_vid['clip_urls'])
        new_vid['clip_urls'] = try_key(v, 'hls', 'hls', new_vid['clip_urls'])
        new_vid['clip_urls'] = try_key(v, 'rtmp', 'rtmp', new_vid['clip_urls'])

        new_vid['legislative_day'] = legislative_day.strftime('%Y-%m-%d')
        new_vid['chamber'] = chamber
        new_vid['session'] =  rtc_utils.current_session(legislative_day.year)

        new_vid['clips'] = get_markers(db, client_name, new_vid['clip_id'])
        #make sure the last clip has a duration
        new_vid['clips'][-1]['duration'] = new_vid['duration'] - new_vid['clips'][-1]['offset']
        print new_vid

def query_api(db, api_url, data=None):

    h = httplib2.Http()
    response, text = h.request(api_url, body=data)

    if response.get('status') == '200':
        items = json.loads(text)['hits']['hits']
        return items

    else:
        PARSING_ERRORS.append('Got something other than 200 status:' % response.get('status'))


