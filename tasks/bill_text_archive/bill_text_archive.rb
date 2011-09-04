# not necessary with the current impl, but let's start making it explicit what each task depends on
require 'searchable'
require 'models/bill'
require 'models/bill_version'

require 'nokogiri'

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
      # -- unlike the mongo-side of things, we pick a curated subset of fields
      bill_fields = Utils.bill_for(bill).merge(
        :sponsor => bill['sponsor'],
        :summary => bill['summary'],
        :keywords => bill['keywords'],
        :last_action => bill['last_action']
      )
      
      type = Utils.govtrack_type_for bill.bill_type
      
      # accumulate a massive string
      bill_version_text = ""
      
      # accumulate an array of version objects
      bill_versions = [] 
      
      # find all the versions of text for that bill, load them in
      version_files = Dir.glob("data/govtrack/#{session}/bill_text/#{type}/#{type}#{bill.number}[a-z]*.txt")
      
      version_files.each do |file|
        # strip off the version code
        code = File.basename file
        code["#{type}#{bill.number}"] = ""
        code[".txt"] = ""
        
        # unique ID
        bill_version_id = "#{bill.bill_id}-#{code}"
        
        # standard GPO version name
        version_name = Utils.bill_version_name_for code
        
        # metadata from associated GPO MODS file
        # -- MODS file is a constant reasonable size no matter how big the bill is
        mods_file = "data/govtrack/#{session}/bill_text/#{type}/#{type}#{bill.number}#{code}.mods.xml"
        
        issued_on = nil # will get filled in
        urls = nil # may not...
        if File.exists?(mods_file)
          mods_doc = Nokogiri::XML open(mods_file)
          issued_on = issued_on_for mods_doc
          urls = urls_for mods_doc
        else
          # backup attempt to get an issued_on, from the dublin core info of the bill doc itself
          # GovTrack adds this Dublin Core information, perhaps by extracting it from the XML
          # If we were ever to switch to GPO directly, this would have to be accounted for
          xml_file = "data/govtrack/#{session}/bill_text/#{type}/#{type}#{bill.number}#{code}.xml"
          if File.exists?(xml_file)
            xml_doc = Nokogiri::XML open(xml_file)
            issued_on = backup_issued_on_for xml_doc
          end
          
          if issued_on.blank?
            # hr81-112-enr is known to trigger this, but that looks like a mistake on GPO's part (HR 81 was never voted on)
            # So if any other bill triggers this, send me a warning so I can check it out.
            if bill_version_id != "hr81-112-enr"
              Report.warning self, "Neither MODS data nor Govtrack's Dublin Core date available for #{bill_version_id}, SKIPPING"
            end
            
            # either way, skip over the bill version, it's probably invalid
            next
          end
        end
        
        
        # read in full text
        full_text = File.read file
        full_text = clean_text full_text
        
        puts "[#{bill.bill_id}][#{code}] Indexing..." if options[:debug]
        
        # commit the version to the version index
        versions_client.index(
          {
            :updated_at => Time.now,
            :bill_version_id => bill_version_id,
            :version_code => code,
            :version_name => version_name,
            :issued_on => issued_on,
            :urls => urls,
            
            :bill => bill_fields,
            :full_text => full_text
          },
          :id => bill_version_id
        )
        
        version_count += 1
        
        # store in the bill object for redundant storage on bill object itself
        bill_version_text << full_text
        bill_versions << {
          :version_code => code,
          :issued_on => issued_on,
          :version_name => version_name,
          :bill_version_id => bill_version_id,
          :urls => urls
        }
      end
      
      if bill_versions.size == 0
        Report.warning self, "No versions with a valid date found for this bill, SKIPPING update of the bill entirely in ES and Mongo"
        next
      end
      
      bill_versions = bill_versions.sort_by {|v| v[:issued_on]}
      
      last_version = bill_versions.last
      last_version_on = last_version[:issued_on]
      
      versions_count = bill_versions.size
      bill_version_codes = bill_versions.map {|v| v[:version_code]}
      
      bills_client.index(
        bill_fields.merge(
          :versions => bill_version_text,
          :version_codes => bill_version_codes,
          :versions_count => versions_count,
          :last_version => last_version,
          :last_version_on => last_version_on,
          :updated_at => Time.now
        ),
        :id => bill.bill_id
      )
      
      puts "[#{bill.bill_id}] Indexed versions for whole bill." if options[:debug]
      
      # Update the bill document in Mongo with an array of version codes
      bill.attributes = {
        :version_info => bill_versions,
        :version_codes => bill_version_codes,
        :versions_count => versions_count,
        :last_version => last_version,
        :last_version_on => last_version_on
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
  
  # expects the bill version's associated MODS XML
  def self.issued_on_for(doc)
    timestamp = doc.at("dateIssued").text
    if timestamp.present?
      Time.parse(timestamp).strftime "%Y-%m-%d"
    else
      nil
    end
  end
  
  # expects the bill version's XML
  def self.backup_issued_on_for(doc)
    timestamp = doc.xpath("//dc:date", "dc" => "http://purl.org/dc/elements/1.1/").text
    if timestamp.present?
      Time.parse(timestamp).strftime "%Y-%m-%d"
    else
      nil
    end
  end
  
  # expects the bill version's associated MODS XML
  def self.urls_for(doc)
    urls = {}
    
    (doc / "url").each do |elem|
      label = elem['displayLabel']
      if label =~ /HTML/i
        urls['html'] = elem.text
      elsif label =~ /XML/i
        urls['xml'] = elem.text
      elsif label =~ /PDF/i
        urls['pdf'] = elem.text
      end
    end
    
    urls
  end
  
end