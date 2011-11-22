import json
import urlparse
import httplib2

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




def get_videos(db, chamber):
    api_url = API_PREFIX + chamber + '?type=video&size=100000'
    videos = query_api(db, api_url)
    for vid in videos:
        v = vid['_source']
        clip_id = v['id']
        mp4 = v['http']
        hls = v['hls']
        rtmp = v['hls']
        print v['name']
        legislative_day = v['name'][v['name'].index('OF')+2:]
        print legislative_day



def query_api(db, api_url):

    h = httplib2.Http()
    response, text = h.request(api_url)

    if response.get('status') == '200':
        items = json.loads(text)['hits']['hits']
        return items

    else:
        PARSING_ERRORS.append('Got something other than 200 status:' % response.get('status'))


