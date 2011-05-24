class BillsFulltextArchive
  
  def self.run(options = {})
    session = options[:session] ? options[:session].to_i : Utils.current_session
    
    bill_count = 0
    version_count = 0
    
    FileUtils.mkdir_p "data/govtrack/#{session}/bill_text"
    unless system("rsync -az govtrack.us::govtrackdata/us/bills.text/#{session}/ data/govtrack/#{session}/bill_text/")
      Report.failure self, "Couldn't rsync to Govtrack.us for bill text."
      return
    end
    
    bills = Bill.where(:session => session).all
    
    bills.each do |bill|
      type = Utils.govtrack_type_for bill.bill_type
      
      # find all the versions of text for that bill, load them in
      versions = Dir.glob("data/govtrack/#{session}/bill_text/#{type}/#{type}#{bill.number}[a-z]*.txt")
      versions.each do |version|
        code = File.basename version
        code["#{type}#{bill.number}"] = ""
        code[".txt"] = ""
        
        puts "[#{bill.bill_id}] version #{code}"
        version_count += 1
      end
      
      bill_count += 1
    end
    
    Report.success self, "Loaded in full text of #{bill_count} bills (#{version_count} versions) for session ##{session} from GovTrack.us."
  end
  
end