require 'cgi'
require 'hmac-sha1'
require 'net/http'

# Require an API key

before do
  if request.post?
    unless SunlightServices.verify params, Environment.config[:services][:shared_secret], Environment.config[:services][:api_name]
      halt 403, 'Bad signature' 
    end
  end
end

# key management endpoints

post '/analytics/create_key/' do
  begin
    ApiKey.create!(
      key: params[:key],
      email: params[:email],
      status: params[:status]
    )
  rescue
    halt 403, "Could not create key, duplicate key or email"
  end
end

post '/analytics/update_key/' do
  if key = ApiKey.where(key: params[:key]).first
    begin
      key.attributes = {email: params[:email], status: params[:status]}
      key.save!
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate API key by the given key'
  end
end

post '/analytics/update_key_by_email/' do
  if key = ApiKey.where(email: params[:email]).first
    begin
      key.attributes = {key: params[:key], status: params[:status]}
      key.save!
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate API key by the given email'
  end
end


class SunlightServices
  
  def self.report(key, endpoint, calls, date, api, shared_secret)
    url = URI.parse "http://services.sunlightlabs.com/analytics/report_calls/"
    
    params = {:key => key, :endpoint => endpoint, :date => date, :api => api, :calls => calls}
    signature = signature_for params, shared_secret
                              
    Net::HTTP.post_form url, params.merge(:signature => signature)
  end
  
  def self.verify(params, shared_secret, api_name)
    return false unless params[:key] and params[:email] and params[:status]
    return false unless params[:api] == api_name
    
    given_signature = params.delete 'signature'
    signature = signature_for params, shared_secret
    
    signature == given_signature
  end

  def self.signature_for(params, shared_secret)
    HMAC::SHA1.hexdigest shared_secret, signature_string(params)
  end

  def self.signature_string(params)
    params.keys.map(&:to_s).sort.map do |key|
      "#{key}=#{CGI.escape((params[key] || params[key.to_sym]).to_s)}"
    end.join '&'
  end
end