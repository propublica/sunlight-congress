class Regulation
  include Api::Model
  publicly :queryable, :searchable
  
  basic_fields :document_type, :document_number, 
    :title, :stage, :article_type,
    :agency_names, :agency_ids, :docket_ids, 
    :url, :pdf_url,
    :publication_date, :posted_at, 

    # only for proposed/final regulations
    :abstract, :effective_on, :rins, :comments_close_on
  
  search_fields :title, :abstract, :text

  cite_key :document_number

  
  include Mongoid::Document
  include Mongoid::Timestamps

  index document_number: 1
  index document_type: 1
  index article_type: 1
  index stage: 1
  index posted_at: 1
  index docket_ids: 1
  index agency_ids: 1

  index effective_on: 1
  index comments_close_on: 1
  index rins: 1

  index citation_ids: 1
  index created_at: 1

  validates_presence_of :document_number
  validates_uniqueness_of :document_number
end