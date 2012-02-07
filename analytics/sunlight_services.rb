require 'cgi'
require 'hmac-sha1'
require 'net/http'

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