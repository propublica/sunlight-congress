# currently very much in beta, I don't understand regulatory data enough yet. this is experimental.

class Regulation

  # elasticsearch behavior

  include Searchable::Model

  result_fields :stage, :rins, :docket_ids, :published_at, :abstract, :title, :effective_at,
    :federal_register_url, :agency_names, :agency_ids, :full_text_xml_url, :document_number
  
  searchable_fields :title, :abstract, :full_text



  # mongo behavior

  include Mongoid::Document
  include Mongoid::Timestamps


  include Queryable::Model
  
  default_order :published_on
  basic_fields :stage, :rins, :docket_ids, :published_at, :abstract, :title, :effective_at,
    :federal_register_url, :agency_names, :agency_ids, :full_text_xml_url, :document_number
  search_fields :title, :abstract


  index :document_number
  index :stage
  index :rins
  index :published_at
  index :effective_at
  index :agencies

  validates_presence_of :document_number
  validates_uniqueness_of :document_number

  # 'proposed', 'final'
  validates_presence_of :stage
end