# encoding: utf-8
require 'us-documents'

# options:
#   meeting_id: only process a particular meeting ID, skip all others
#   force: always backup each document (ignore .backed file)

    # Uses @unitedstates house hearing scraper documents to get hearing documents
    # Planning to get additional documents from FDsys and perhaps Senate Committees

class CongressionalDocuments
  def self.run(options = {})
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
      puts "[#{house_event_id}] Processing..."

      chamber = hearing_data["chamber"]
      hearing_type_code = hearing_data["house_meeting_type"]
      hearing_title = hearing_data["topic"]
      # extract docs from witness and meeting document
      witnesses = hearing_data["witnesses"]
      meeting_documents = hearing_data["meeting_documents"]
      hearing_datetime = Time.zone.parse(hearing_data["occurs_at"]).utc

      if (meeting_documents != nil)
        hearing_data["meeting_documents"].each do |hearing_doc|
          puts house_event_id
          published_on = Time.zone.parse(hearing_doc["published_on"]).utc
          if (published_on == nil)
            published_on = hearing_datetime
            puts published_on
          end
          text = nil
          urls = Array.new
          # no urls for that document, skipping to next document

          if not hearing_doc["urls"] 
            print "SKIP"
            next
          end

          puts hearing_doc["urls"]
          puts house_event_id

          url_base = File.basename(hearing_doc["urls"][0]["url"])
          urls = []
          hearing_doc["urls"].each do |u|
            url = {}
            url["url"] = u["url"]
            urls.push(url)
            if u["file_found"] == true
              # extract text
              text_name = url_base.sub ".pdf", ".txt"
              folder = house_event_id / 100
              text_file = "data/unitedstates/congress/committee/meetings/house/#{folder}/#{house_event_id}/#{text_name}"
              text = File.read text_file
              text_list = text.split(' ')
              if text_list.count < 150
                text_preview = text
              else
                text_preview = text_list[0...150].join(' ')
              end
              url["permalink"] = "http://unitedstates.sunlightfoundation.com/#{folder}/#{house_event_id}/#{url_base}"
              check_and_save(url_base, house_event_id, options) 
            else
              text = nil
              text_preview = nil
              puts text_preview
            end # file found
          end #each url

          extn = File.extname url_base
          url_base_name = File.basename url_base, extn
          puts url_base_name

          id = "house-#{house_event_id}-#{url_base_name}"

          document = {
            document_id: id,
            # document_type: '_report',
            document_type_name: "#{chamber} committee document",
            # hearing information
            chamber: chamber,
            committee_id: hearing_data["committee"],
            subcommittee_suffix: hearing_data["subcommittee"],
            congress: hearing_data["congress"],
            house_event_id: hearing_data["house_event_id"],
            hearing_type_code: hearing_data["house_meeting_type"],
            hearing_title: hearing_data["topic"],
            # document information
            published_on: published_on,
            bill_id: hearing_doc["bill_id"],
            description: hearing_doc["description"],
            type: hearing_doc["type"],
            type_name: hearing_doc["type_name"],
            version_code: hearing_doc["version_code"],
            bioguide_id: hearing_doc["bioguide_id"],
            occurs_at: hearing_datetime,
            urls: urls,
            text: text,
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
              url["permalink"] = "http://unitedstates.sunlightfoundation.com/#{folder}/#{house_event_id}/#{url_base}" 
              urls.push(url)
            end
          end

          published_on = Time.zone.parse(witness_doc["published_on"]).utc
          if (published_on == nil)
            published_on = hearing_datetime
          end

          # extract text
          text_name = url_base.sub ".pdf", ".txt"
          folder = house_event_id / 100
          text_file = "data/unitedstates/congress/committee/meetings/house/#{folder}/#{house_event_id}/#{text_name}"
          if File.exists?(text_file)
            text = File.read text_file
            text_list = text.split(' ')
            if text_list.count < 150
              text_preview = text
            else
              text_preview = text_list[0...150].join(' ')
              puts text_preview
            end
            # save
            check_and_save(url_base, house_event_id, options)
          else
            puts "no text file found"
            text = nil
            text_preview = nil
          end

          extn = File.extname url_base
          url_base_name = File.basename url_base, extn
          puts url_base_name

          id = "house-#{house_event_id}-#{url_base}"

          document = {
            document_id: id,
            # document_type: '_report',
            document_type_name: "#{chamber} witness document",
            # hearing information
            chamber: chamber,
            committee_id: hearing_data["committee"],
            subcommittee_suffix: hearing_data["subcommittee"],
            congress: hearing_data["congress"],
            house_event_id: house_event_id,
            hearing_type_code: hearing_type_code,
            hearing_title: hearing_title,
            # witness information
            witness_first: witness["first_name"],
            witness_last: witness["last_name"],
            witness_middle: witness["middle_name"],
            witness_organization: witness["organization"],
            witness_position: witness["position"],
            witness_type: witness["witness_type"],
            # doc information
            published_on: published_on,
            description: witness_doc["description"],
            type: witness_doc["type"],
            type_name: witness_doc["type_name"],
            type_name: witness_doc["type_name"],
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
