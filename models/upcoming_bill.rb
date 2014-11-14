class UpcomingBill
  include Api::Model
  publicly :queryable

  basic_fields :bill_id,
    :range, :legislative_day, :scheduled_at,
    :chamber, :congress,
    :source_type, :url,
    # senate-only
    :context,
    # house-only
    :description, :consideration, :floor_id, :bill_url


  # experimental: RSS support
  rss title: "legislative_day",
      guid: "url", # not actually unique
      link: "url",
      pubDate: "scheduled_at",
      description: "bill_id"


  include Mongoid::Document
  include Mongoid::Timestamps

  index chamber: 1
  index congress: 1
  index legislative_day: 1
  index scheduled_at: 1
  index source_type: 1
  index bill_id: 1
  index range: 1

  # support an orderly ordering of upcoming bills
  index({legislative_day: 1, range: 1})
end