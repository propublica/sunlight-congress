class Hit
  include Mongoid::Document
  
  index created_at: 1
  index method: 1
  index method_type: 1
  index key: 1
  index format: 1
  index user_agent: 1
  index app_version: 1
  index os_version: 1
  index app_channel: 1
  
  index({key: 1, method: 1})
end