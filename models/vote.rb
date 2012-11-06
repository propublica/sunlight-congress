class Vote

  # searchable behavior
  
  include ::Searchable::Model

  result_fields :how, :roll_id, :number, :year, :chamber, :session, 
    :result, :bill_id, :voted_at, :last_updated, :roll_type, :question, 
    :required, :vote_type, :passage_type, :amendment_id, :vote_breakdown
  
  searchable_fields :question, "bill.last_version_text", "bill.summary", "bill.keywords", "bill.official_title", "bill.popular_title", "bill.short_title", "amendment.purpose"

  
  
  include ::Queryable::Model
  
  default_order :voted_at
  
  basic_fields :how, :roll_id, :number, :year, :chamber, :session, 
    :result, :bill_id, :voted_at, :last_updated, :roll_type,  :question, 
    :required, :vote_type, :passage_type, :amendment_id, :vote_breakdown
  
  search_fields :question
  
  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index roll_id: 1
  index chamber: 1
  index session: 1
  index type: 1
  index result: 1
  index voted_at: 1
  index roll_type: 1
  index vote_type: 1
  index passage_type: 1
  index required: 1
  index year: 1
  index number: 1
  index how: 1
  index bill_id: 1
  index amendment_id: 1
  
  field :roll_id
  validates_uniqueness_of :roll_id, :allow_nil => true
end