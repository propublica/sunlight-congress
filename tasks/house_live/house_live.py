import re 
from pysrt import SubRipTime, SubRipItem, SubRipFile
import json
import rtc_utils
import urlparse
import httplib2
from datetime import datetime, timedelta
import time as timey
from dateutil.parser import parse as dateparse
import os
from htmlentitydefs import name2codepoint
import subprocess
from boto.s3.connection import S3Connection
from boto.s3.key import Key
import re

ESCAPE_CHARS_RE = re.compile(r'(?<!\\)(?P<char>[&|+\-!(){}[\]^"~*?:])')
API_PREFIX = 'http://govflix.com/api/'
PARSING_ERRORS = []

AWS_ACCESS_KEY_ID = None
AWS_SECRET_ACCESS_KEY = None
BUCKET_NAME = 'assets.realtimecongress.org'

def run(db, es, options = {}):
    
    
    if options.has_key('s3'):
        global AWS_ACCESS_KEY_ID
        global AWS_SECRET_ACCESS_KEY
        AWS_ACCESS_KEY_ID = options['s3']['key']
        AWS_SECRET_ACCESS_KEY = options['s3']['secret']

    archive = False
    captions = False
        
    if options.has_key('archive'): archive = options['archive']
    if options.has_key('captions'): captions = options['captions']

    get_videos(db, es, 'houselive.gov', 'house', archive, captions )

    if PARSING_ERRORS:
        db.note("Errors while parsing timestamps", {'errors': PARSING_ERRORS})


def htmlentitydecode(s):
    return re.sub('&(%s);' % '|'.join(name2codepoint), lambda m: unichr(name2codepoint[m.group(1)]), s).replace('\n', ' ').replace('\r', ' ')


def get_cap_end(caps, count):
    c = None
    for item in caps[count+1:]:
        if item['type'] == 'text':
            return float(item['time'])
    return None

def push_to_s3(filename, s3name):
    conn = S3Connection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    bucket = conn.create_bucket(BUCKET_NAME)
    k = Key(bucket)
    k.key = 'srt/%s' % s3name
    k.set_contents_from_filename(filename)
    k.set_acl('public-read')

    return 'http://assets.realtimecongress.org/srt/%s' % s3name

def get_captions(client_name, clip_id):
    h = httplib2.Http()
    g_url = 'http://%s/JSON.php?clip_id=%s' % ( client_name, clip_id)
    response, j = h.request(g_url)
    dirname = os.getcwd() + "/data/granicus/srt/%s/" % client_name
    filename = dirname + "%s.srt" % clip_id
    subs = SubRipFile()

    if response.get('status') == '200':
        captions = []
        try:
            j = json.loads(j, strict=False)[0]
        except ValueError:
            ts = re.sub('([{,]\s+)([a-z]+)(: ")', lambda s: '%s"%s"%s' % (s.groups()[0], s.groups()[1], s.groups()[2]), j).replace("\\", "")
            try:
                j = json.loads(ts, strict=False)[0]
            except UnicodeDecodeError:
                ts = unicode(ts, errors='ignore')
                j = json.loads(ts, strict=False)[0]
        except:
            j = False

        sub_count = 0
        for item in j: 
            if item["type"] == "text":
                cap = item["text"]
                offset = round(float(item["time"]), 3)
                captions.append({'time': offset, 'text': cap})        
                end = get_cap_end(j, sub_count)
                if end:
                    subtitle = SubRipItem(index=sub_count, start=SubRipTime(seconds=offset), end=SubRipTime(seconds=end), text=cap)
                    subs.append(subtitle)
           
            sub_count = sub_count + 1
        
        try:
            subs.save(path=filename, encoding="utf-8")
        except IOError:
            p = subprocess.Popen('mkdir -p %s' % dirname, shell=True, stdout=subprocess.PIPE)
            t = p.wait()

            subs.save(path=filename, encoding="utf-8")
            
        s3_url = push_to_s3(filename, '%s/%s.srt' % (client_name, clip_id))
        return (captions, s3_url)
    else:
        return ([], '')
         
   


def get_markers(db, client_name, clip_id, congress, chamber):
    api_url = API_PREFIX + client_name + '?type=marker&size=100000'
    data = '{"filter": { "term": { "video_id": %s}}, "sort": [{"offset":{"order":"asc"}}]}' % clip_id
    markers = query_api(db, api_url, data)

    clips = []
    bills = []
    legislators = []
    bioguide_ids = []
    rolls = []

    for m in markers:
        m_new = m['_source']
        c = {
            'offset': m_new['offset'],
            'events': [htmlentitydecode(m_new['name']).strip(),],
            'time': m_new['datetime']
        }
        if m != markers[-1]:  #if it's not the last one
            c['duration'] = markers[markers.index(m)+1]['_source']['offset'] - m_new['offset']

        year = dateparse(m_new['datetime']).year

        legis, bio_ids = rtc_utils.extract_legislators(c['events'][0], chamber, db)
        b = rtc_utils.extract_bills(c['events'][0], congress)
        r = rtc_utils.extract_rolls(c['events'][0], chamber, year)
        
        if legis: c['legislator_names'] = legis; legislators.extend(legis)
        if b: c['bioguide_ids'] = b; bioguide_ids.extend(bio_ids)
        if r: c['rolls'] = r; rolls.extend(r)
        if b: c['bills'] = b; bills.extend(b)

        clips.append(c)

    return (clips, bills, legislators, bioguide_ids, rolls)

def try_key(data, key, name, new_data):
    if data.has_key(key):
        new_data[name] = data[key]
        return new_data
    else:
        return new_data

def get_videos(db, es, client_name, chamber, archive=False, captions=False):
    api_url = API_PREFIX + client_name + '?type=video'
    data = '{ "sort": [ {"datetime": {"order": "desc" }} ]  }'
    if archive:
        api_url += '&size=100000'
    else:
        api_url += '&size=2'
    videos = query_api(db, api_url, data)
    vcount = 0
    for vid in videos:
        
        v = vid['_source']

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

        new_vid['clips'], new_vid['bills'], new_vid['legislator_names'], new_vid['bioguide_ids'], new_vid['rolls'] = get_markers(db, client_name, new_vid['clip_id'], new_vid['session'], chamber)

        #make sure the last clip has a duration
        if len(new_vid['clips']) > 0:
            new_vid['clips'][-1]['duration'] = new_vid['duration'] - new_vid['clips'][-1]['offset']

        if captions:
            new_vid['captions'], new_vid['caption_srt_file'] = get_captions(client_name, new_vid['clip_id'])
            print new_vid['caption_srt_file']
        
        db['videos'].save(new_vid) 
        vcount += 1

        #index clip objects in elastic search
        if captions:
            for c in new_vid['clips']:
                clip = {
                        'id': "%s-%s" % (new_vid['video_id'], new_vid['clips'].index(c)),
                        'video_id': new_vid['video_id'],
                        'video_clip_id': new_vid['clip_id'],
                        'offset': c['offset'],
                        'duration': c['duration'],
                }
                clip = try_key(c, 'legislator_names', 'legislator_names', clip)
                clip = try_key(c, 'rolls', 'rolls', clip)
                clip = try_key(c, 'events', 'events', clip)
                clip = try_key(c, 'bills', 'bills', clip)
                clip = try_key(c, 'bioguide_ids', 'bioguide_ids', clip)
                
                if new_vid.has_key('caption_srt_file'):
                    clip['srt_link'] = new_vid['caption_srt_file'],

                if new_vid.has_key('captions'):
                    clip['captions'] = get_clip_captions(new_vid, c)

                resp = es.save(clip, 'clips', clip['id'])
            
            if resp['ok'] == False:
                print resp
                PARSING_ERRORS.append('Could not successfully save to elasticsearch - video_id: %s' % resp['_id'])

            es.connection.refresh()

    db.success("Updated or created %s legislative days for %s video" % (client_name, vcount))

def get_clip_captions(video, clip):

    captions = []
    for cap in video['captions']:
        c_time = round(float(cap['time']), 3)
        start = round(float(clip['offset']), 3)
        end = round(float(clip['duration']) + start, 3)
        if (c_time >= start and c_time < end) or (c_time < start):  # need the second condition to snag captions that begin before the first 'offset'
            captions.append(cap)

    #turn captions into one large string for elastic search
    cap_str = ""
    for cap in captions:
        cap_str += cap['text'] + ' '
        
    return cap_str
     

def query_api(db, api_url, data=None):

    h = httplib2.Http()
    response, text = h.request(api_url, body=data)

    if response.get('status') == '200':
        items = json.loads(text)['hits']['hits']
        return items

    else:
        PARSING_ERRORS.append('Got something other than 200 status:' % response.get('status'))

def escape_query(text):
    return ESCAPE_CHARS_RE.sub(r'\\\g<char>', text)
