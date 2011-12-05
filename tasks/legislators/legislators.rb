require 'sunlight'

class Legislators

  def self.run(options = {})
    Sunlight::Base.api_key = options[:config]['sunlight_api_key']
    
    bad_legislators = []
    count = 0
    
    legislators = Sunlight::Legislator.all_where :all_legislators => 1
    
    legislators.each do |api_legislator|
      legislator = Legislator.find_or_initialize_by :bioguide_id => api_legislator.bioguide_id
      
      legislator.attributes = attributes_from api_legislator
      
      unless legislator.save
        bad_legislators << {:attributes => legislator.attributes, :error_messages => legislator.errors.full_messages}
      end
      
      count += 1
    end
    
    if bad_legislators.any?
      Report.warning self, "Failed to save #{bad_legislators.size} legislators, last bad one attached", :bad_legislator => bad_legislators.first
    end
    
    if count > Legislator.count
      Report.warning self, "#{count - Legislator.count} legislators didn't get saved regardless of validations."
    end
    
    Report.success self, "Processed #{count} legislators from API - total count in database now: #{Legislator.count}"
  end
    
    
  def self.attributes_from(api_legislator)
    {
      # bioguide_id covered in initialization
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