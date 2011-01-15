# log all hits in the database, along with their API key

def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end

after do
  if request.get? and params[:captures]
    query_hash = request.env['rack.request.query_hash']
    
    # kept separately, don't need reproduced
    query_hash.delete 'sections'
    query_hash.delete 'apikey'
    
    Hit.create(
      :sections => (params[:sections] || '').split(','),
      :method => params[:captures][0],
      :format => params[:captures][1],
      :key => api_key,
      :user_agent => request.env['HTTP_USER_AGENT'],
      :app_version => request.env['HTTP_X_OS_VERSION'],
      :query_hash => process_query_hash(request.env['rack.request.query_hash']),
      :created_at => Time.now.utc # don't need updated_at
    )
  end
end

# split out any dot separated fields into their appropriate hash structures
def process_query_hash(hash)
  new_hash = {}
  
  hash.each do |key, value|
    subkeys = key.split "."
    if subkeys.size == 1 # nothing special
      new_hash[key] = value
    else
      sub_hash = {}
      subkeys.reverse.each_with_index do |subkey, i|
        if i == 0
          sub_hash[subkeys[i+1]] = subkeys[i]
        else
          if (i+1) < subkeys.size # still one to go after this
            sub_hash = {subkeys[i+1] => sub_hash}
          end
        end
      end
      new_hash = new_hash.merge sub_hash
    end
  end
  
  new_hash
end

class Hit
  include Mongoid::Document
  
  index :method
  index :key
  index :sections
  index :format
  index :user_agent
  index :app_version
  index :os_version
end

def process_query_hash(hash)
  new_hash = {}
  
  hash.each do |key, value|
    if key.is_a? String
      subkeys = key.split "."
      if subkeys.size == 1 # nothing special
        new_hash[key] = value
      else
        sub_hash = {}
        subkeys = subkeys.reverse
        subkeys.each_with_index do |subkey, i|
          if i == 0
            sub_hash[subkeys[i+1]] = subkeys[i]
          else
            if (i+1) < subkeys.size # still one to go after this
              sub_hash = {subkeys[i+1] => sub_hash}
            end
          end
        end
        new_hash = deep_merge new_hash, sub_hash
      end
    else
      new_hash[key] = value
    end
  end
  
  new_hash
end

def deep_merge(first, second)
  target = first.dup
  
  second.keys.each do |key|
    if second[key].is_a? Hash and first[key].is_a? Hash
      target[key] = deep_merge target[key], second[key]
      next
    end
    
    target[key] = second[key]
  end
  
  target
end