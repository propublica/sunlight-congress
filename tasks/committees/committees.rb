require 'sunlight'

class Committees
  
  def self.run(options = {})
    Sunlight::Base.api_key = options[:config]['sunlight_api_key']
    
    bad_committees = []
    count = 0
    
    senate = Sunlight::Committee.all_for_chamber 'Senate'
    house = Sunlight::Committee.all_for_chamber 'House'
    joint = Sunlight::Committee.all_for_chamber 'Joint'
    
    (senate + house + joint).each do |api_committee|
      committee = Committee.find_or_initialize_by committee_id: api_committee.id
      
      committee.attributes = attributes_for api_committee
      
      unless committee.save
        bad_committees << {:attributes => committee.attributes, :error_messages => committee.errors.full_messages}
      end
      
      count += 1
    end
    
    if bad_committees.any?
      Report.warning self, "Failed to save #{bad_committees.size} committee, last bad one attached", :bad_committee => bad_committees.first
    end
    
    Report.success self, "Processed #{count} committees from API - total count in database now: #{Committee.count}"
  end
  
  def self.attributes_for(api_committee)
    attributes = {
      name: api_committee.name,
      chamber: api_committee.chamber.downcase,
      committee_id: api_committee.id
    }

    if api_committee.subcommittees
      attributes[:subcommittees] = api_committee.subcommittees.map {|sc| attributes_for sc}
    end
    
    attributes
  end
end