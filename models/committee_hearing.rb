class CommitteeHearing
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :chamber
  index :committee_id
  index :occurs_at
  
  field :legislative_day
  
  def self.default_order
    :occurs_at
  end
  
  def self.basic_fields
    [:chamber, :committee_id, :occurs_at, :description, :room]
  end
  
  def self.search_fields
    [:description]
  end
end