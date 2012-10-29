class ApiKey
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :key
  field :email
  field :status
  
  validates_presence_of :key
  validates_presence_of :email
  validates_presence_of :status
  validates_uniqueness_of :key
  validates_uniqueness_of :email
  
  index key: 1
  index email: 1
  index status: 1
  
  def self.allowed?(key)
    !ApiKey.where(key: key, status: 'A').first.nil?
  end
end