class Document
  include Api::Model
  publicly :queryable, :searchable

  basic_fields :document_id, :posted_at, :published_at,
    :document_type, :document_type_name,
    :title, :source_url, :url,
    :gao_id, :categories 
     
  search_fields :title, :categories, :text

  cite_key :document_id
  

  
  include Mongoid::Document
  include Mongoid::Timestamps

  # basic guarantees
  validates_uniqueness_of :document_id
  validates_presence_of :document_id
  validates_presence_of :posted_at
  validates_presence_of :url
  validates_presence_of :title
  validates_presence_of :document_type

  index document_id: 1
  index posted_at: 1
  index document_type: 1

  index notice_type: 1
  index party: 1
  index chamber: 1
  index for_date: 1
  index order_code: 1

  index estimate_id: 1
  index categories: 1

  index gao_id: 1
  index citation_ids: 1
end