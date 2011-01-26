class Document
  include Mongoid::Document
  include Mongoid::Timestamps
  
  index :posted_at
  index :document_type
  
  # document-specific fields
  # whip_notice
  index :notice_type
  index :party
  index :chamber
  index :for_date
  
  def self.default_order
    :posted_at
  end
  
  def self.basic_fields
    [:posted_at, :document_type, :url]
  end
end