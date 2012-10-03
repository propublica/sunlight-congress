class Legislator
  include Mongoid::Document
  include Mongoid::Timestamps

  index bioguide_id: 1
  index govtrack_id: 1
  index in_office: 1
  index chamber: 1
  index "ids.bioguide" => 1
  index "ids.thomas" => 1
end