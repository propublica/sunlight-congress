# not necessary with the current impl, but let's start making it explicit what each task depends on
require 'searchable'
require 'models/bill'
require 'models/bill_version'

require 'nokogiri'
require 'curb'

class BillTextArchive
  
  def self.run(options = {})
    session = options[:session] ? options[:session].to_i : Utils.current_session
    
    bill_count = 0
    version_count = 0
    
    versions_client = Searchable.client_for 'bill_versions'
    bills_client = Searchable.client_for 'bills'
    
    bill_ids = Bill.where(:session => session, :abbreviated => false).distinct :bill_id
    
    if options[:bill_id]
      bill_ids = [options[:bill_id]]
    elsif options[:limit]
      bill_ids = bill_ids.first options[:limit].to_i
    end

    warnings = []
    
    bill_ids.each do |bill_id|
      bill = Bill.where(:bill_id => bill_id).first
      
      type = bill.bill_type
      
      # find all the versions of text for that bill
      version_files = Dir.glob("data/gpo/BILLS/#{session}/#{type}/#{type}#{bill.number}-#{session}-[a-z]*.htm")
      
      if version_files.empty?
        puts "[#{bill.bill_id}] Skipping bill, GPO has no version information for it" if options[:debug]
        next
      end
      
      
      # accumulate a massive string
      last_bill_version_text = ""
      
      # accumulate an array of version objects
      bill_versions = [] 
      
      # pick the subset of fields from the bill document that will appear on bills and bill_versions
      # -- unlike the mongo-side of things, we pick a curated subset of fields
      bill_fields = Utils.bill_for(bill).merge(
        :sponsor => bill['sponsor'],
        :summary => bill['summary'],
        :keywords => bill['keywords'],
        :last_action => bill['last_action']
      )
      
      version_files.each do |file|
        # strip off the version code
        bill_version_id = File.basename file, File.extname(file)
        code = bill_version_id.match(/\-(\w+)$/)[1]
        
        # standard GPO version name
        version_name = Utils.bill_version_name_for code
        
        # metadata from associated GPO MODS file
        # -- MODS file is a constant reasonable size no matter how big the bill is
        
        mods_file = "data/gpo/BILLS/#{session}/#{type}/#{bill_version_id}.mods.xml"
        mods_doc = nil
        if File.exists?(mods_file)
          mods_doc = Nokogiri::XML open(mods_file)
        end
        
        issued_on = nil # will get filled in
        urls = nil # may not...
        if mods_doc
          issued_on = issued_on_for mods_doc

          urls = urls_for mods_doc

          if issued_on.blank?
            warnings << {:message => "Had MODS data but no date available for #{bill_version_id}, SKIPPING", :bill_version_id => bill_version_id}
            next
          end

        else
          puts "[#{bill.bill_id}][#{code}] No MODS data" if options[:debug]
          
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
              warnings << {:message => "Neither MODS data nor Govtrack's Dublin Core date available for #{bill_version_id}, SKIPPING", :bill_version_id => bill_version_id}
            end
            
            # either way, skip over the bill version, it's probably invalid
            next
          end
        end
        
        
        # read in full text
        full_doc = Nokogiri::HTML File.read(file)
        full_text = full_doc.at("pre").text
        full_text = clean_text full_text
        
        puts "[#{bill.bill_id}][#{code}] Indexing..." if options[:debug]
        
        version_attributes = {
          :updated_at => Time.now,
          :bill_version_id => bill_version_id,
          :version_code => code,
          :version_name => version_name,
          :issued_on => issued_on,
          :urls => urls,
          
          :bill => bill_fields,
          :full_text => full_text
        }

        # commit the version to the version index
        versions_client.index(
          version_attributes,
          :id => bill_version_id
        )

        # archive it in MongoDB for easy reference in other scripts
        version_archive = BillVersion.find_or_initialize_by :bill_version_id => bill_version_id
        version_archive.attributes = version_attributes
        version_archive.save!
        
        version_count += 1
        
        # store in the bill object for redundant storage on bill object itself
        last_bill_version_text = full_text 
        bill_versions << {
          :version_code => code,
          :issued_on => issued_on,
          :version_name => version_name,
          :bill_version_id => bill_version_id,
          :urls => urls
        }
      end
      
      if bill_versions.size == 0
        warnings << {:message => "No versions with a valid date found for bill #{bill_id}, SKIPPING update of the bill entirely in ES and Mongo", :bill_id => bill_id}
        next
      end
      
      bill_versions = bill_versions.sort_by {|v| v[:issued_on]}
      
      last_version = bill_versions.last
      last_version_on = last_version[:issued_on]
      
      versions_count = bill_versions.size
      bill_version_codes = bill_versions.map {|v| v[:version_code]}
      
      puts "[#{bill.bill_id}] Indexing versions for whole bill..." if options[:debug]

      bills_client.index(
        bill_fields.merge(
          :versions => last_bill_version_text,
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

    if warnings.any?
      Report.warning self, "Warnings found during date parsing of bill text metadata", :warnings => warnings
    end
    
    Report.success self, "Loaded in full text of #{bill_count} bills (#{version_count} versions) for session ##{session} from GovTrack.us."
  end
  
  def self.clean_text(text)
    # weird artifact at end
    text.gsub! '<all>', ''
    
    # remove unneeded whitespace
    text.gsub! "\n", " "
    text.gsub! "\t", " "
    text.gsub! /\s{2,}/, ' '

    # get rid of dumb smart quotes
    text.gsub! '``', '"'
    text.gsub! "''", '"'

    # remove underscore lines
    text.gsub! /_{2,}/, ''

    # de-hyphenate words broken up over multiple lines
    text.gsub!(/(\w)\-\s+(\w)/) {$1 + $2}
    
    text.strip
  end
  
  # expects the bill version's associated MODS XML
  def self.issued_on_for(doc)
    elem = doc.at("dateIssued")
    timestamp = elem ? elem.text : nil
    if timestamp.present?
      Utils.utc_parse(timestamp).strftime "%Y-%m-%d"
    else
      nil
    end
  end
  
  # expects the bill version's XML
  def self.backup_issued_on_for(doc)
    timestamp = doc.xpath("//dc:date", "dc" => "http://purl.org/dc/elements/1.1/").text
    if timestamp.present?
      Utils.utc_parse(timestamp).strftime "%Y-%m-%d"
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