# log all hits in the database, along with their API key

def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end

after queryable_route do
  query_hash = request.env['rack.request.query_hash']
  
  # kept separately, don't need reproduced
  query_hash.delete 'sections'
  query_hash.delete 'apikey'
  
  # don't care about keeping pagination info
  query_hash.delete 'per_page'
  query_hash.delete 'page'
  
  query_hash = process_query_hash query_hash
  
  hit = Hit.create!(
    key: api_key,
    
    method_type: 'queryable',
    method: params[:captures][0],
    format: params[:captures][1],
    
    query_hash: query_hash,
    sections: (params[:sections] || '').split(','),
    
    user_agent: request.env['HTTP_USER_AGENT'],
    app_version: request.env['HTTP_X_APP_VERSION'],
    os_version: request.env['HTTP_X_OS_VERSION'],
    app_channel: request.env['HTTP_X_APP_CHANNEL'],

    created_at: Time.now.utc # don't need updated_at
  )

  HitReport.log! Time.zone.now.strftime("%Y-%m-%d"), api_key, params[:captures][0]
end

after searchable_route do
  query_hash = request.env['rack.request.query_hash']
  
  # kept separately, don't need reproduced
  query_hash.delete 'sections'
  query_hash.delete 'apikey'
  query_hash.delete 'query'
  query_hash.delete 'search'
  
  # don't care about keeping pagination info
  query_hash.delete 'per_page'
  query_hash.delete 'page'
  
  query_hash = process_query_hash query_hash

  method = "search.#{params[:captures][0]}"
  
  hit = Hit.create(
    key: api_key,
    
    method_type: 'searchable',
    method: method,
    format: params[:captures][1],
    
    query: params[:query],
    search: params[:search],
    
    query_hash: query_hash,
    sections: (params[:sections] || '').split(','),
    
    user_agent: request.env['HTTP_USER_AGENT'],
    app_version: request.env['HTTP_X_APP_VERSION'],
    os_version: request.env['HTTP_X_OS_VERSION'],
    app_channel: request.env['HTTP_X_APP_CHANNEL'],
    created_at: Time.now.utc # don't need updated_at
  )

  HitReport.log! Time.zone.now.strftime("%Y-%m-%d"), api_key, method
end

def process_query_hash(hash)
  new_hash = {}
  hash.each do |key, value|
    bits = key.split '.'
    break_out new_hash, bits, value
  end
  new_hash
end

# helper function to recursively rewrite a hash to break out dot-separated fields into sub-documents
def break_out(hash, keys, final_value)
  if keys.size > 1
    first = keys.first
    rest = keys[1..-1]
    
    # default to on
    hash[first] ||= {}
    
    break_out hash[first], rest, final_value
  else
    hash[keys.first] = final_value
  end
end