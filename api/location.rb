module Location

  # PA-5
  # http://ec2-184-73-61-66.compute-1.amazonaws.com/boundaries/cd/?contains=41,-78
  # WY-At Large
  # http://ec2-184-73-61-66.compute-1.amazonaws.com/boundaries/cd/?contains=42.96,-108.09

  # given a lat/lng, or zip, turn this into a where clause
  # acceptable to apply to the legislators OR districts mongodb collections

  # return a condition that would match both the specific district *and* the whole state

  def self.location_to_districts(lat, lng)

  end


  def self.zip_to_districts(zip)

  end

end