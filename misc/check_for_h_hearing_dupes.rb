require 'congress'
Congress.key='sunlight9'

all = []
1.upto(6) do |page|
  results = Congress.hearings(:page => page, :per_page => 50, :chamber => 'house', :congress => 113, :order => 'occurs_at__asc', :house_hearing_id__exists => true).results
  all.concat results
end
fl = File.new('./hearings_with_ids', 'w+')
fl.write(JSON.dump(all))


dupes = []
possible_dupes = JSON.parse(File.read('./hearings_with_ids.json'))
possible_dupes.each do |hearing|
  dupe = Congress.hearings(:chamber => hearing['chamber'], :congress => hearing['congress'],
                           :committee_id => hearing['committee_id'], :occurs_at => hearing['occurs_at'],
                           :house_hearing_id__exists => false,
                           :fields => '_id,committee_id,chamber,description,room,occurs_at')
  dupes << dupe
end
fl = File.new('./hearing_dupes.json', 'w+')
fl.write(JSON.dump(dupes))

dupes = JSON.parse(File.read('./hearing_dupes.json')).map{|d| d['results']}.flatten
dupe_ids = dupes.map{|d| d['_id']}
fl = File.new('./hearing_dupe_ids.json', 'w+')
fl.write(JSON.dump(dupe_ids))