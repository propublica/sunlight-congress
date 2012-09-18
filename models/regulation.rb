# currently very much in beta, I don't understand regulatory data enough yet. this is experimental.

class Regulation

  # elasticsearch behavior

  include Searchable::Model

  result_fields :document_type, :stage, :rins, :docket_ids, :publication_date, :published_at, :abstract, :title, :effective_at,
    :federal_register_url, :agency_names, :agency_ids, :full_text_xml_url, :document_number, :year,
    # public inspection fields
    :pdf_url, :pdf_updated_at, :num_pages, :raw_text_url, :filed_at
  
  searchable_fields :title, :abstract, :full_text



  # mongo behavior

  include Mongoid::Document
  include Mongoid::Timestamps


  include Queryable::Model
  
  default_order :published_on
  basic_fields :stage, :rins, :docket_ids, :published_at, :abstract, :title, :effective_at,
    :federal_register_url, :agency_names, :agency_ids, :full_text_xml_url, :document_number, :year
  search_fields :title, :abstract

  cite_key :document_number
  cite_field "usc.extracted_ids"


  index document_number: 1
  index document_type: 1
  index stage: 1
  index rins: 1
  index published_at: 1
  index effective_at: 1
  index agencies: 1
  index "usc.extracted_ids" => 1
  index year: 1
  index filed_at: 1
  index pdf_updated_at: 1
  index indexed: 1

  validates_presence_of :document_number
  validates_uniqueness_of :document_number
  validates_presence_of :stage # 'proposed', 'final'
end