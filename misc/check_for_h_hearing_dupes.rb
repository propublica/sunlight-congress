# this must be run in the current directory
require './config/environment'
require 'congress'

Congress.key='sunlight9'

all = []
#Find the new ones- house_event_id is not in the old records
1.upto(47) do |page|
  results = Congress.hearings(:page => page, :per_page => 50, :chamber => 'house', :congress => 113, :order => 'occurs_at__asc', :house_event_id__exists => true).results
  all.concat results
end
fl = File.new('./hearings_with_ids.json', 'w+')
fl.write(JSON.dump(all))
fl.close


dupes = []
possible_dupes = JSON.parse(File.read('./hearings_with_ids.json'))
# find matches based on the detals for the new records, but they will not have house event id
possible_dupes.each do |hearing|
  dupe = Congress.hearings(:chamber => hearing['chamber'], :congress => hearing['congress'],
                           :committee_id => hearing['committee_id'], :occurs_at => hearing['occurs_at'],
                           :house_event_id__exists => false,
                           :fields => '_id,committee_id,chamber,description,room,occurs_at')
  dupes << dupe
end
fl = File.new('./hearing_dupes.json', 'w+')
fl.write(JSON.dump(dupes))

dupes = JSON.parse(File.read('./hearing_dupes.json')).map{|d| d['results']}.flatten
dupe_ids = dupes.map{|d| d['_id']}
# fl = File.new('./hearing_dupe_ids.json', 'w+')
# fl.write(JSON.dump(dupe_ids))

dupe_ids.each do |id|
	dupe = Hearing.find id
	puts dupe
	#dupe.delete
end
        


