# not necessary with the current impl, but let's start making it explicit what each task depends on
require 'searchable'
require 'models/bill'
require 'models/bill_version'

class BillTextArchive
  
  def self.run(options = {})
    session = options[:session] ? options[:session].to_i : Utils.current_session
    
    bill_count = 0
    version_count = 0
    
    
    unless options[:skip_sync]
      puts "Rsyncing to GovTrack for bill text..." if options[:debug]
      FileUtils.mkdir_p "data/govtrack/#{session}/bill_text"
      unless system("rsync -az govtrack.us::govtrackdata/us/bills.text/#{session}/ data/govtrack/#{session}/bill_text/")
        Report.failure self, "Couldn't rsync to Govtrack.us for bill text."
        return
      end
      puts "Finished rsync to GovTrack." if options[:debug]
    end
    
    
    versions_client = Searchable.client_for 'bill_versions'
    bills_client = Searchable.client_for 'bills'
    
    bill_ids = Bill.where(:session => session, :abbreviated => false).distinct :bill_id
    
    if options[:bill_id]
      bill_ids = [options[:bill_id]]
    elsif options[:limit]
      bill_ids = bill_ids.first options[:limit].to_i
    end
    
    bill_ids.each do |bill_id|
      bill = Bill.where(:bill_id => bill_id).first
      
      # pick the subset of fields from the bill document that will appear on bills and bill_versions
      # unlike the mongo-side of things, we pick a curated subset of fields
      bill_fields = Utils.bill_for(bill).merge(
        :sponsor => bill['sponsor'],
        :summary => bill['summary'],
        :keywords => bill['keywords'],
        :last_action => bill['last_action']
      )
      
      type = Utils.govtrack_type_for bill.bill_type
      
      # accumulate a massive string
      bill_versions = ""
      # accumulate an array of version codes
      bill_version_codes = [] 
      
      # find all the versions of text for that bill, load them in
      version_files = Dir.glob("data/govtrack/#{session}/bill_text/#{type}/#{type}#{bill.number}[a-z]*.txt")
      
      version_files.each do |file|
        code = File.basename file
        code["#{type}#{bill.number}"] = ""
        code[".txt"] = ""
        
        bill_version_id = "#{bill.bill_id}-#{code}"
        
        full_text = File.read file
        full_text = clean_text full_text
        
        puts "[#{bill.bill_id}][#{code}] Indexing..." if options[:debug]
        
        # commit the version to the version index
        versions_client.index(
          {
            :updated_at => Time.now,
            :bill_version_id => bill_version_id,
            :version_code => code,
            
            :bill => bill_fields,
            :full_text => full_text
          },
          :id => bill_version_id
        )
        
        version_count += 1
        
        # store in the bill object for redundant storage on bill object itself
        bill_versions << full_text
        bill_version_codes << code
      end
      
      bills_client.index(
        bill_fields.merge(
          :versions => bill_versions,
          :version_codes => bill_version_codes,
          :versions_count => bill_version_codes.size,
          :updated_at => Time.now
        ),
        :id => bill.bill_id
      )
      
      puts "[#{bill.bill_id}] Indexed versions for whole bill." if options[:debug]
      
      # Update the bill document in Mongo with an array of version codes
      bill.attributes = {
        :version_codes => bill_version_codes,
        :versions_count => bill_version_codes.size
      }
      bill.save!
      puts "[#{bill.bill_id}] Updated bill with version codes." if options[:debug]
      
      bill_count += 1
    end
    
    # make sure queries are ready
    versions_client.refresh
    bills_client.refresh
    
    Report.success self, "Loaded in full text of #{bill_count} bills (#{version_count} versions) for session ##{session} from GovTrack.us."
  end
  
  def self.clean_text(text)
    # Remove the interspersed self-referential bill code lines (i.e. •SRES 115 IS)
    text.gsub! /•[^\n]+/, ''
    
    # remove the line and page numbers
    text.gsub! /\s{2,}\d+\s{2,}(\d+\s{2,})?/, ' '
    
    # remove unneeded whitespace
    text.gsub! "\n", " "
    text.gsub! "\t", " "
    text.gsub! /\s{2,}/, ' '
    
    # de-hyphenate words broken up over multiple lines
    text.gsub!(/(\w)\-\s+(\w)/) {$1 + $2}
    
    text.strip
  end
  
end