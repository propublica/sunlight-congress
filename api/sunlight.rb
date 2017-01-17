## API Key syncing

before do
  if request.post? and !SunlightServices.verify(params, Environment.config[:services][:shared_secret], Environment.config[:services][:api_name])
    halt 403, 'Bad signature'
  end
end

post '/analytics/replicate_key/:key/' do
  unless params[:key].present? and params[:status].present? and params[:email].present?
    halt 403, "Missing a key, email, and/or status: #{params.inspect}"
  end

  puts "Replicating key for: #{params.inspect}"

  begin
    key = ApiKey.find_or_create_by key: params[:key]
    key.email = params[:email]
    key.status = params[:status]
    key.save!
  rescue Exception => ex
    Email.report Report.exception("SunlightServices", "Error replicating key.", ex, {key: key.attributes.dup})
    halt 500
  end
end
