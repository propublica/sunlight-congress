# fully anonymous aggregate records of search queries sent to the system, for analytics

class SearchReport
  include Mongoid::Document
  include Mongoid::Timestamps # easy way of seeing first and last time it got searched for

  field :query
  field :method
  field :count, type: Fixnum

  index query: 1
  index method: 1
  index count: 1

  def self.log!(query, method)
    collection = Mongoid.session(:default)[:search_reports]
    collection.find({query: query, method: method}).upsert({"$inc" => {"count" => 1}})
  end
end