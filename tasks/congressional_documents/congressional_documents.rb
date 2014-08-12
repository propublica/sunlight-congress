# encoding: utf-8
require 'us-documents'

# options:
#   meeting_id: only process a particular meeting ID, skip all others
#   force: always backup each document (ignore .backed file)

    # Uses @unitedstates house hearing scraper documents to get hearing documents
    # Planning to get additional documents from FDsys and perhaps Senate Committees

class CongressionalDocuments
  def self.run(options = {})
    amazon_bucket = "http://unitedstates.sunlightfoundation.com/congress/committee/meetings/house"
    meeting_count = 0
    document_count = 0
    path = "data/unitedstates/congress"
    house_json = File.read "#{path}/committee_meetings_house.json"
    house_data = Oj.load house_json
    house_data.each do |hearing_data|
      # skip if no data or documents
      next if hearing_data == nil
      next if (hearing_data["meeting_documents"] == nil && hearing_data["witnesses"] == nil)
      house_event_id = hearing_data["house_event_id"]
      puts "[#{house_event_id}] Found in hearings JSON..." if options[:debug]
      next if options[:meeting_id] and (options[:meeting_id] != house_event_id.to_s)
      #puts "[#{house_event_id}] Processing..."

      chamber = hearing_data["chamber"]
      hearing_type_code = hearing_data["house_meeting_type"]
      hearing_title = hearing_data["topic"]
      # extract docs from witness and meeting document
      witnesses = hearing_data["witnesses"]
      meeting_documents = hearing_data["meeting_documents"]
      hearing_datetime = Time.zone.parse(hearing_data["occurs_at"]).utc

      if (meeting_documents != nil)
        hearing_data["meeting_documents"].each do |hearing_doc|
          published_at = Time.zone.parse(hearing_doc["published_on"]).utc
          if (published_at == nil)
            published_at = hearing_datetime
          end
          urls = Array.new
          # no urls for that document, skipping to next document

          if not hearing_doc["urls"] 
            puts "SKIP"
            next
          end

          url_base = File.basename(hearing_doc["urls"][0]["url"])
          urls = []
          text = nil
          text_preview = nil
          hearing_doc["urls"].each do |u|
            url = {}
            url["url"] = u["url"]
            urls.push(url)

            if u["file_found"] == true and url_base.include? ".pdf"
              # extract text
              text_name = url_base.sub ".pdf", ".txt"
              folder = house_event_id / 100
              text_file = "data/unitedstates/congress/committee/meetings/house/#{folder}/#{house_event_id}/#{text_name}"
              
              text = File.read text_file
              text_preview = text
              text_preview.gsub! (/\.{3,}/), '   '
              text_preview.gsub! (/_{3,}/), '\n'
              text_preview.gsub! (/\\f/), ' '
              text_list = text_preview.split(' ')
              if text_list.count < 150
                text_preview = text_preview
              else
                text_preview = text_list[0...150].join(' ')
              end

              if text_preview == ''
                text_preview == nil
              end

              url["permalink"] = "#{amazon_bucket}/#{folder}/#{house_event_id}/#{url_base}"
              check_and_save(url_base, house_event_id, options) 
            end # file found
          end #each url

          doc_type = hearing_data['type_name']
          if doc_type == nil
            doc_type = 'Other'
          end

          extn = File.extname url_base
          url_base_name = File.basename url_base, extn

          id = "house-#{house_event_id}-#{url_base_name}"

          document = {
            document_id: id,
            document_type: doc_type,
            # hearing information
            chamber: chamber,
            committee_id: hearing_data["committee"],
            subcommittee_suffix: hearing_data["subcommittee"],
            committee_names: hearing_data["committee_names"],
            congress: hearing_data["congress"],
            house_event_id: hearing_data["house_event_id"],
            hearing_type_code: hearing_data["house_meeting_type"],
            hearing_title: hearing_data["topic"],
            # document information
            published_at: published_at,
            bill_id: hearing_doc["bill_id"],
            description: hearing_doc["description"],
            type: doc_type,
            version_code: hearing_doc["version_code"],
            bioguide_id: hearing_doc["bioguide_id"],
            occurs_at: hearing_datetime,
            urls: urls,
            text: text,
            text_preview: text_preview,
          }

          # save to elastic search
          collection = "congressional_documents"
          Utils.es_store! collection, id, document
          document_count += 1
        end # end of meeting doc loop
      end
      next if hearing_data["witnesses"] == nil
      hearing_data["witnesses"].each do |witness|
        # no witnesses and meeting docs are already loaded, skipping to next meeting
        next if hearing_data["witnesses"]== nil 
        # no documents for a particular witness, skipping witness
        redo if (defined?(witness["documents"])).nil?
        witness["documents"].each do |witness_doc|
          # no url for the partuclar document, skipping doc
          next if (defined?(witness_doc["urls"][0]["url"])).nil?
          urls = []
          url_base = File.basename(witness_doc["urls"][0]["url"])
          witness_doc["urls"].each do |u|
            url = {}
            url["url"] = u["url"]
            if u["file_found"] == true
              folder = house_event_id / 100
              url["permalink"] = "#{amazon_bucket}/#{folder}/#{house_event_id}/#{url_base}" 
              urls.push(url)
            end
          end

          published_at = Time.zone.parse(witness_doc["published_on"]).utc
          if (published_at == nil)
            published_at = hearing_datetime
          end

          doc_type = hearing_data['type_name']
          if doc_type == nil
            doc_type = 'Other'
          end

          # extract text
          text_name = url_base.sub ".pdf", ".txt"
          folder = house_event_id / 100
          text_file = "data/unitedstates/congress/committee/meetings/house/#{folder}/#{house_event_id}/#{text_name}"
          text = nil
          text_preview = nil
          if File.exists?(text_file)
            text = File.read text_file

            text_preview = text
            text_preview.gsub! (/\.{3,}/), '   '
            text_preview.gsub! (/_{3,}/), '\n'
            text_preview.gsub! (/\\f/), ' '
            text_list = text_preview.split(' ')
            if text_list.count < 150
              text_preview = text_preview
            else
              text_preview = text_list[0...150].join(' ')
            end

            if text_preview == ''
              text_preview == nil
            end
            # save
            check_and_save(url_base, house_event_id, options)
          end

          extn = File.extname url_base
          url_base_name = File.basename url_base, extn

          id = "house-#{house_event_id}-#{url_base_name}"

          witness_info = {
            first_name: witness["first_name"],
            last_name: witness["last_name"],
            middle_name: witness["middle_name"],
            organization: witness["organization"],
            position: witness["position"],
            witness_type: witness["witness_type"],
          }
          
          document = {
            document_id: id,
            # document_type: '_report',
            document_type_name:  hearing_data['document_type_name'],
            # hearing information
            chamber: chamber,
            committee_names: hearing_data["committee_names"],
            committee_id: hearing_data["committee"],
            subcommittee_suffix: hearing_data["subcommittee"],
            congress: hearing_data["congress"],
            house_event_id: house_event_id,
            hearing_type_code: hearing_type_code,
            hearing_title: hearing_title,
            # witness information
            witness: witness_info,
            # doc information
            published_at: published_at,
            description: witness_doc["description"],
            type: doc_type,
            bioguide_id: witness_doc["bioguide_id"],
            occurs_at: hearing_datetime,
            urls: urls,
            text: text,
            text_preview: text_preview,
          }

          # save to elastic search
          collection = "congressional_documents"
          Utils.es_store! collection, id, document      
        end # loop through witness doc
      end # loop through witness
    end # loop through hearing
    Report.success self, "Processed #{document_count} House documents."
  end # self.run

  def self.check_and_save(file_name, house_event_id, options)
    folder = house_event_id / 100
    destination = "meetings/house/#{folder}/#{house_event_id}/#{file_name}"
    source = "data/unitedstates/congress/committee/meetings/house/#{folder}/#{house_event_id}/#{file_name}"
    last_version_backed = source + ".backed"
    if options[:force] or !File.exists?(last_version_backed)
      Utils.write last_version_backed, Time.now.to_i.to_s
      #def self.backup!(bucket, source, destination, options = {})
      Utils.backup!("congressional_documents", source, destination)
      puts "[#{source}] Uploaded HTML to S3."
    else
      puts "[#{source}] Already uploaded to S3."
    end
  end # end of check_and_save
end # class
