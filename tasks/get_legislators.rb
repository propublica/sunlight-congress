class GetLegislators

  def self.run(options = {})
    start = Time.now
    bad_legislators = []
    
    count = 0
    
    Sunlight::Legislator.all_where(:all_legislators => 1).each do |api_legislator|
      if legislator = Legislator.first(:conditions => {:bioguide_id => api_legislator.bioguide_id})
        #puts "[Legislator #{legislator.bioguide_id}] Updated"
      else
        legislator = Legislator.new :bioguide_id => api_legislator.bioguide_id
        #puts "[Legislator #{legislator.bioguide_id}] Created"
      end
      
      legislator.attributes = attributes_from api_legislator
      
      unless legislator.save
        bad_legislators << {:attributes => legislator.attributes, :error_messages => legislator.errors.full_messages}
      end
      
      count += 1
    end
    
    Report.success self, "Updated #{count} legislators from API - total count in database now: #{Legislator.count}"
    
    if bad_legislators.any?
      Report.failure self, "Failed to save #{bad_legislators.size} legislators, last bad one attached", :bad_legislator => bad_legislators.first
    end
  end
    
    
  def self.attributes_from(api_legislator)
    {
      :in_office => api_legislator.in_office,
      :govtrack_id => api_legislator.govtrack_id,
      :votesmart_id => api_legislator.votesmart_id,
      :crp_id => api_legislator.crp_id,
      :first_name => api_legislator.firstname,
      :nickname => api_legislator.nickname,
      :last_name => api_legislator.lastname,
      :name_suffix => api_legislator.name_suffix,
      :state => api_legislator.state,
      :district => api_legislator.district,
      :party => api_legislator.party,
      :title => api_legislator.title,
      :gender => api_legislator.gender,
      :phone => api_legislator.phone,
      :website => api_legislator.website,
      :congress_office => api_legislator.congress_office,
      :twitter_id => api_legislator.twitter_id,
      :youtube_url => api_legislator.youtube_url,
      
      :chamber => {
          'Rep' => 'house',
          'Sen' => 'senate',
          'Del' => 'house',
          'Com' => 'house'
        }[api_legislator.title]
    }
  end
  
end