class BillsFulltextArchive
  
  def self.run(options = {})
    session = options[:session] ? options[:session].to_i : Utils.current_session
    
    bill_count = 0
    version_count = 0
    
    
    puts "Rsyncing to GovTrack for bill text..." if options[:debug]
    FileUtils.mkdir_p "data/govtrack/#{session}/bill_text"
    unless system("rsync -az govtrack.us::govtrackdata/us/bills.text/#{session}/ data/govtrack/#{session}/bill_text/")
      Report.failure self, "Couldn't rsync to Govtrack.us for bill text."
      return
    end
    
    
#     client = elastic_search_for 'bills', 'bill_text'
    
    
    fields = Bill.basic_fields + [:summary]
    bills = Bill.where(:session => session, :abbreviated => false).only(fields)
    
      
    # debug
    bills = bills.limit(5)
    
    bills.all.each do |bill|
      type = Utils.govtrack_type_for bill.bill_type
      
      # find all the versions of text for that bill, load them in
      version_files = Dir.glob("data/govtrack/#{session}/bill_text/#{type}/#{type}#{bill.number}[a-z]*.txt")
      version_files.each do |file|
        code = File.basename file
        code["#{type}#{bill.number}"] = ""
        code[".txt"] = ""
        
#         full_text = File.read file
#         
#         document = {
#           :version_code => code,
#           :full_text => full_text
#         }
#         
#         fields.each do |field|
#           document.merge! field => bill.attributes[field.to_s]
#         end
#         
#         client.index(
#           document,
#           :id => "#{bill.bill_id}-#{code}"
#         )
#         
#         puts "[#{bill.bill_id}][#{code}] Indexed." if options[:debug]
        
        version_count += 1
      end
      
      bill_count += 1
    end
    
#     # make sure queries are ready
#     client.refresh
    
    Report.success self, "Loaded in full text of #{bill_count} bills (#{version_count} versions) for session ##{session} from GovTrack.us."
  end
  
end