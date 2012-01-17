# currently very much in beta, I don't understand regulatory data enough yet. this is experimental.

class Regulation
  include Mongoid::Document
  include Mongoid::Timestamps


  include Queryable::Model
  
  default_order :published_on
  basic_fields :regulation_id, :fr_id, :stage, :rins, :docket_ids, :published_on, :abstract, :title
  search_fields :title, :abstract

  index :regulation_id # combination of fr_id and stage
  
  index :fr_id
  index :stage
  index :rins
  index :published_on

  field :published_on, :type => String

  validates_presence_of :regulation_id
  validates_uniqueness_of :regulation_id

  validates_presence_of :fr_id
  # 'proposed', 'final'
  validates_presence_of :stage
end