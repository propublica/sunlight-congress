class DistrictsKml

  # Generates KML files for every CD.
  # 
  # options:
  #   district: do a particular district. In boundary service form: "ne-1", "ca-12"

  def self.run(options = {})
    # failsafe, should be many less records than this
    maximum = 100000

    page = 1
    per_page = options[:per_page] ? options[:per_page].to_i : 100

    count = 0

    errors = []

    while page < (maximum / per_page)
      puts "Fetching page #{page}..."

      if options[:district]
        districts = [options[:district]]
      else
        districts = districts_for page, per_page, options

        if districts.nil?
          Report.failure self, "Failure paging through districts on page #{page}, aborting"
          return
        end
      end

      districts.each do |district|
        puts "[#{district}] Downloading KML..."
        
        url = kml_url_for district
        destination = destination_for district
        kml = Utils.download url, {destination: destination}.merge(options)
        if kml.nil?
          errors << {district: district, message: "Couldn't download KML for this district"}
          next
        end

        puts "[#{district}] Wrote KML to disk."
        count += 1
      end

      if districts.size < per_page
        break
      else
        page += 1
      end
    end

    if errors.any?
      Report.warning self, "Found #{errors.size} district lookup errors", errors: errors
    end

    Report.success self, "Wrote #{count} districts to KML."
  end

  def self.districts_for(page, per_page, options = {})
    offset = (page - 1) * per_page
    limit = per_page

    host = Environment.config['location']['host']
    url = "http://#{host}/boundaries/?sets=cd&limit=#{limit}&offset=#{offset}"

    response = Utils.download url, {json: true}.merge(options)
    return nil unless response

    response['objects'].map {|object| object['name']}
  end

  def self.kml_url_for(district, options = {})
    host = Environment.config['location']['host']
    boundary_district = district.gsub(" ", "-").gsub(/[\(\)]/, '').downcase
    "http://#{host}/boundaries/cd/#{boundary_district}/simple_shape?format=kml"
  end

  def self.destination_for(district)
    state, number = district.split " "
    if district =~ /At Large/i
      number = 0
    elsif district =~ /defined/i
      number = -1
    end

    output_district = "#{state.upcase}-#{number}"
    "data/districts/kml/#{output_district}.kml"
  end

end