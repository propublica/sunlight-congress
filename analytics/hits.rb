# log all hits in the database, along with their API key

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
      :query_hash => request.env['rack.request.query_hash'],
      :created_at => Time.now.utc # don't need updated_at
    )
  end
end

def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end

class Hit
  include Mongoid::Document
  
  index :method
  index :key
  index :sections
  index :format
  index :user_agent
  index "query_hash.bill_id"
  index "query_hash.vote_id"
  index "query_hash.bioguide_id"
end