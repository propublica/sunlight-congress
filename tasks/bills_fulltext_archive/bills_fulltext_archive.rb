require 'searchable'
require 'models/bill'
require 'models/bill_version'

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
    
    
    versions_client = Searchable.client_for 'bill_versions'
    bills_client = Searchable.client_for 'bills'
    
    
    bills = Bill.where(:session => session, :abbreviated => false).only(:bill_type, :number, :bill_id)
      
    if options[:limit]
      bills = bills.limit options[:limit].to_i
    end
    
    bills.all.each do |bill|
      type = Utils.govtrack_type_for bill.bill_type
      
      # find all the versions of text for that bill, load them in
      version_files = Dir.glob("data/govtrack/#{session}/bill_text/#{type}/#{type}#{bill.number}[a-z]*.txt")
      version_files.each do |file|
        code = File.basename file
        code["#{type}#{bill.number}"] = ""
        code[".txt"] = ""
        
        bill_version_id = "#{bill.bill_id}-#{code}"
        
        if versions_client.get(bill_version_id, {:fields => "_id"})
          unless options[:refresh]
            puts "Skipping #{bill_version_id}, already in the system." if options[:debug]
            next
          end
        end
        
        full_text = File.read file
        full_text = clean_text full_text
        
        document = {
          :bill_version_id => bill_version_id,
          :version_code => code,
          :full_text => full_text,
          :bill => Utils.bill_for(bill.bill_id) # basic fields
        }
        
        # commit the version to the version index
        versions_client.index(
          document,
          :id => bill_version_id
        )
        
        puts "[#{bill.bill_id}][#{code}] Indexed." if options[:debug]
        
        version_count += 1
      end
      
      bill_count += 1
    end
    
    # make sure queries are ready
    versions_client.refresh
    
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
    
    text
  end
  
end