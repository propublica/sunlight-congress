class Document
  include Api::Model
  publicly :queryable, :searchable

  basic_fields :document_id, :document_type, :document_type_name,
    :posted_at, :published_on,
    :title, :categories,
    :source_url, :url
     
  search_fields :title, :categories, :text,
    "gao_report.description"

  cite_key :document_id
  

  
  include Mongoid::Document
  include Mongoid::Timestamps

  validates_uniqueness_of :document_id
  validates_presence_of :posted_at
  validates_presence_of :url

  index document_id: 1
  index document_type: 1
  index posted_at: 1
  index categories: 1
  index citation_ids: 1
  index created_at: 1

  index "gao_report.gao_id" => 1
end