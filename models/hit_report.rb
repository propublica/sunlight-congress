# a second class of hit logging, structured precisely to report back to central

class HitReport
  include Mongoid::Document
  
  field :day, type: String
  field :key, type: String
  field :method, type: String
  field :count, type: Integer

  index({day: 1, key: 1, method: 1})

  def self.log!(day, key, method)
    collection = Mongoid.session(:default)[:hit_reports]
    collection.find({day: day, key: key, method: method}).upsert({"$inc" => {"count" => 1}})
  end

  def self.for_day(day)
    collection = Mongoid.session(:default)[:hit_reports]
    collection.find({day: day}).select(_id: 0).to_a
  end
end