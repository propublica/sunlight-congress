require 'curl'
require 'multi_json'

module Location

  # Useful examples:
  # PA-5 - latitude: 41,    longitude: -78
  # WY-0 - latitude: 42.96, longitude: -108.09
  # 30165 - spans two states 

  # given an array of district hashes [{state, district}, ...]
  # turn this into a conditions hash that will match on representatives 
  # and senators for this area
  def self.district_to_legislators(districts)
    and_senators = []
    states = []
    districts.each do |district|
      if !states.include?(district[:state])
        states << district[:state]
        and_senators << {state: district[:state], chamber: "senate"}
      end
    end

    {"$or" => (districts + and_senators), in_office: true}
  end


  def self.response_to_districts(response)
    unless response.present? and response.is_a?(Hash) and response['objects']
      raise LocationException.new("Invalid response from location server.")
    end

    # latitude/longitude should return just one, but just in case
    response['objects'].map do |object|
      pieces = object['name'].split " "
      if object['name'] =~ /at Large/i
        {state: pieces[0], district: 0}
      else
        {state: pieces[0], district: pieces[1].to_i}
      end
    end
  end

  def self.zip_to_districts(zip)
    [{district: 5, state: "NY"}]
  end

  def self.url_for(latitude, longitude)
    # sanitize
    latitude = latitude.to_s.to_f 
    longitude = longitude.to_s.to_f
  
    "http://#{Environment.config['location']['host']}/boundaries/cd/?contains=#{latitude},#{longitude}"
  end

  def self.response_for(url)
    body = fetch url
    MultiJson.load body

  rescue MultiJson::DecodeError => ex
    raise LocationException.new("Error parsing JSON from location server.")
  end

  def self.fetch(url)
    curl = Curl::Easy.new url
    curl.follow_location = true # follow redirects
    curl.perform
    curl.body_str

  rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
    Curl::Err::RecvError, Timeout::Error, Curl::Err::HostResolutionError, 
    Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH, Errno::ECONNREFUSED

    raise LocationException.new("Error looking up location.")
  end

  class LocationException < Exception; end
end