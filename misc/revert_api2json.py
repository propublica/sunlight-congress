# need to remap congressional documents data so dumping data in url to json to reimport :( it should load text from disk
import requests
import json

url = "http://congress.api.sunlightfoundation.com/congressional_documents/search?apikey=sunlight9&per_page=100&fields=document_id,document_type,chamber,committee_id,subcommittee_suffix,committee_names,congress,house_event_id,hearing_type_code,hearing_title,document_type_name,published_at,bill_id,description,type,version_code,bioguide_id,occurs_at,urls,witness"
data = []

def call_congress_api(page):
  endpoint = url
  response = requests.get(endpoint)

  response_url = response.url
  # debug
  # print response_url
  return response.json()

def read_response(resp):
  for r in resp["results"]:
      if r['occurs_at'] == None:
            print r, "NO occurs_at"
      item = {}
      # item['bill_ids']= [r['bill_id']],
      item['chamber']= r['chamber']
      item['committee']= r['committee_id']
      item['committee_names']= r['committee_names']
      item['congress']= r['congress']
      item['house_event_id']= r['house_event_id']
      item['subcommittee']= r['subcommittee_suffix']
      item['occurs_at']= r['occurs_at']

      

      doc = [{
            "description": r['description'],
            "published_on": r['published_at'],
            "type_name": r['type'],
            "urls": [
                  {
                  'file_found': True,
                  'url': r['urls'][0]['url'],
                  }
            ]
      }]

      if r.has_key('witness'):
            item['witnesses'] = [{
                  "first_name": r['witness']['first_name'], 
                  "honorific": r['witness'], 
                  "house_event_id": r['house_event_id'], 
                  "last_name": r['witness']['last_name'], 
                  "middle_name": r['witness']['middle_name'], 
                  "organization": r['witness']['organization'], 
                  "position": r['witness']['position'], 
                  "witness_type": r['witness']['witness_type'],
                  "documents": doc,
            }]

            doc = [{
                  "description": r['description'],
                  "published_on": r['published_at'],
                  "type_name": r['type'],
                  "urls": [
                        {
                        'file_found': True,
                        'url': r['urls'][0]['url'],
                        }
                  ]
            }]

      else:
            item['meeting_documents']= [{
                  "bill_id": r['bill_id'], 
                  "bioguide_id": r['bioguide_id'], 
                  "description": r['description'],
                  "published_on": r['published_at'], 
                  "type_name": r['type'], 
                  "urls": [{
                        "url": r['urls'][0]['url'],
                        "file_found": True, 
                  }],
                  "version_code": r['version_code'],
                  "occurs_at": r["occurs_at"],  
                  "topic": r['hearing_title'], 
            }]
      data.append(item)
    

page = 1
total_pages = 50#208
# retrieve witness information
while page <= total_pages:
  resp = call_congress_api(page)
  pages = read_response(resp)
  page += 1
  total_pages = total_pages
      
with open("data/unitedstates/congress/committee_meetings_house.json", "w") as hearing_file:
  json.dump(data, hearing_file)
 
           
            
           