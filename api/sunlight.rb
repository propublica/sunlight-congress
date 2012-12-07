## API Key syncing

before do
  if request.post? and !SunlightServices.verify(params, Environment.config[:services][:shared_secret], Environment.config[:services][:api_name])
    halt 403, 'Bad signature' 
  end
end

post '/analytics/create_key/' do
  unless ApiKey.new(key: params[:key], email: params[:email], status: params[:status]).save
    halt 403, "Could not create key, duplicate key or email"
  end
end

post '/analytics/update_key/' do
  unless key = ApiKey.where(key: params[:key]).first
    halt 404, 'Could not locate API key by the given key'
  end
  
  key.attributes = {email: params[:email], status: params[:status]}
  unless key.save
    halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
  end
end

post '/analytics/update_key_by_email/' do
  unless key = ApiKey.where(email: params[:email]).first
    halt 404, 'Could not locate API key by the given email'
  end

  key.attributes = {key: params[:key], status: params[:status]}
  unless key.save
    halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
  end
end