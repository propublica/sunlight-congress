require 'curl'
require 'oj'

module Location

  # PA-5
  # http://ec2-184-73-61-66.compute-1.amazonaws.com/boundaries/cd/?contains=41,-78
  # WY-At Large
  # http://ec2-184-73-61-66.compute-1.amazonaws.com/boundaries/cd/?contains=42.96,-108.09
  

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


  def self.location_to_districts(lat, lng)
    url = url_for lat, lng
    body = fetch url
    response = Oj.load body

    # lat/lng should return just one, but just in case
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

  def self.url_for(lat, lng)
    # sanitize
    lat = lat.to_s.to_f 
    lng = lng.to_s.to_f
  
    "http://#{Environment.config['location']['host']}/boundaries/cd/?contains=#{lat},#{lng}"
  end

  def self.fetch(url)
    curl = Curl::Easy.new url
    curl.follow_location = true # follow redirects
    curl.perform
    curl.body_str
  rescue Curl::Err::ConnectionFailedError, Curl::Err::PartialFileError, 
    Curl::Err::RecvError, Timeout::Error, Curl::Err::HostResolutionError, 
    Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETUNREACH, Errno::ECONNREFUSED
    throw LocationException.new("Error looking up location at #{url}")
  end

  class LocationException < Exception; end
end