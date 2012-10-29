require './analytics/sunlight_services'

# Require an API key

before do
  if request.get?
    unless ApiKey.allowed? api_key
      halt 403, 'API key required, you can obtain one from http://services.sunlightlabs.com/accounts/register/'
    end
  else
    unless SunlightServices.verify params, config[:services][:shared_secret], config[:services][:api_name]
      halt 403, 'Bad signature' 
    end
  end
end


# Accept the API key through the query string or the x-apikey header

def api_key
  params[:apikey] || request.env['HTTP_X_APIKEY']
end


# key management endpoints

post '/analytics/create_key/' do
  begin
    ApiKey.create! :key => params[:key],
        :email => params[:email],
        :status => params[:status]
  rescue
    halt 403, "Could not create key, duplicate key or email"
  end
end

post '/analytics/update_key/' do
  if key = ApiKey.where(:key => params[:key]).first
    begin
      key.attributes = {:email => params[:email], :status => params[:status]}
      key.save!
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate api key by the given key'
  end
end

post '/analytics/update_key_by_email/' do
  if key = ApiKey.where(:email => params[:email]).first
    begin
      key.attributes = {:key => params[:key], :status => params[:status]}
      key.save!
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate api key by the given email'
  end
end