include Api::Routes

before(queryable_route) {request.env['start_time'] = Time.now}
before(searchable_route) {request.env['start_time'] = Time.now}

after(queryable_route) {log_hit}
after(searchable_route) {log_hit}

def log_hit
  return unless response.status == 200

  query_hash = process_query_hash request.env['rack.request.query_hash']
  query_hash.delete 'apikey'
  query_hash.delete 'per_page'
  query_hash.delete 'page'

  method_type = (env["PATH_INFO"] =~ /^\/search/) ? "search" : "query"
  method = params[:captures][0]

  hit = Hit.create!(
    key: api_key,
    
    method_type: method_type,
    method: method,
    format: (params[:format] || "json"),
    
    query_hash: query_hash,
    
    user_agent: request.env['HTTP_USER_AGENT'],
    app_version: request.env['HTTP_X_APP_VERSION'],
    os_version: request.env['HTTP_X_OS_VERSION'],
    app_channel: request.env['HTTP_X_APP_CHANNEL'],

    created_at: Time.now.utc,
    elapsed: (Time.now - request.env['start_time'])
  )

  HitReport.log! Time.zone.now.strftime("%Y-%m-%d"), api_key, method
end

def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end


# processing query hash to remove periods from keys

def process_query_hash(hash)
  new_hash = {}
  hash.each do |key, value|
    bits = key.split '.'
    break_out new_hash, bits, value
  end
  new_hash
end

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