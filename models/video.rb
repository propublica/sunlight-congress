class Video
  include Mongoid::Document
  
  def self.unique_keys
    [:clip_id]
  end
  
  def self.filter_keys
    {
      :full_length => Boolean
    }
  end
  
  def self.order_keys
    [:add_date]
  end
end