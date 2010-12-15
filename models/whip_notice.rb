class WhipNotice  
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :posted_at
  index :party
  index :chamber
  index :notice_type
  
  def self.default_order
    :posted_at
  end
  
  def self.basic_fields
    [:posted_at, :party, :chamber, :type, :url]
  end
end