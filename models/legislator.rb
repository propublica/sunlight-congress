class Legislator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :bioguide_id
  field :govtrack_id
  field :in_office, :type => Boolean
  field :chamber
  
  index :bioguide_id, :unique => true
  index :govtrack_id, :unique => true
  index :in_office
  index :chamber
  
  validates_presence_of :bioguide_id
  validates_presence_of :govtrack_id
  validates_inclusion_of :in_office, :in => [true, false]
  validates_presence_of :chamber
  
  def self.unique_keys
    [:bioguide_id, :govtrack_id]
  end
  
  def self.search_keys
    {
      :chamber => String,
      :in_office => Boolean,
      :last_name => String
    }
  end
  
  def self.basic_fields
    [ 
      :bioguide_id, 
      :govtrack_id, 
      :crp_id, 
      :votesmart_id, 
      :chamber, 
      :in_office, 
      :first_name, 
      :nickname, 
      :last_name, 
      :name_suffix, 
      :state, 
      :district, 
      :party, 
      :title, 
      :gender, 
      :phone, 
      :website, 
      :twitter_id, 
      :youtube_url, 
      :congress_office
    ]
  end
  
  def self.order_keys
    [:last_name]
  end
end