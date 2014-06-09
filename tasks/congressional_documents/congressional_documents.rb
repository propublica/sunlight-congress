# encoding: utf-8
require 'us-documents'

class CongressionalDocuments
    def self.run(options = {})
    puts "starting congress documents"

    # Uses @unitedstates house hearing scraper documents to get hearing documents
    # Planning to get additional documents from FDsys and perhaps Senate Committees 


    # meeting documents
    path = "data/unitedstates/congress"
    house_json = File.read "#{path}/committee_meetings_house.json"

    house_data = Oj.load house_json
    house_data.each do |hearing_data|
      puts "starting hearing data loop"
      if (hearing_data != nil)
        puts "found hearing data"
        if (hearing_data["meeting_documents"] == nil && hearing_data["witnesses"] == nil)
          puts "no doc information"
          next #skip records without documents
        end

        puts "found docs"

        chamber = hearing_data["chamber"]
        committee_id = hearing_data["committee"]
        subcommittee_suffix = hearing_data["subcommittee"]
        congress = hearing_data["congress"]
        house_event_id = hearing_data["house_event_id"]
        puts house_event_id
        hearing_type_code = hearing_data["house_meeting_type"]
        hearing_title = hearing_data["topic"]

        # extract docs from witness and meeting documents
        witnesses = hearing_data["witnesses"]
        meeting_documents = hearing_data["meeting_documents"]
        puts "extracted meeting info"
        if (meeting_documents != nil)
          puts "found meeting documents"
          hearing_data["meeting_documents"].each do |hearing_doc| 
            puts "starting document loop"
            # hearing_doc["bill_id"]
            # hearing_doc["description"]
            # hearing_doc["type"]
            # hearing_doc["type_name"]
            # hearing_doc["version_code"]
            # hearing_doc["bioguide_id"]
            if (hearing_doc["publish_date"] != nil)
              hearing_datetime = Time.zone.parse(hearing_doc["publish_date"]).utc
            else
              hearing_datetime = nil
            end

            urls = Array.new 
            if hearing_doc["urls"]
              hearing_doc["urls"].each do |url|
                puts "found url"
                urls.push(url)
                # ass s3 url
                # if (url["file_found"] == true)
                #   ## save to s3
                #   #  from utils use self.backup!(bucket, source, destination, options = {}) to save
                ### would like to add an extract full text function here
                # end
              end
              puts "looing for basename"
              url_base = File.basename(hearing_doc["urls"][0]["url"])
              puts url_base
              puts "basename working"


            else
              # sometimes there is no url
              puts "no url !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
              next
            end

            
            id = "house-#{house_event_id}-#{url_base}"

            document = {
              document_id: id,
              # document_type: '_report',
              document_type_name: "#{chamber} Committee Document",

              # hearing information
              chamber: hearing_data["chamber"],
              committee_id: hearing_data["committee"],
              subcommittee_suffix: hearing_data["subcommittee"],
              congress: hearing_data["congress"],
              house_event_id: hearing_data["house_event_id"],
              hearing_type_code: hearing_data["house_meeting_type"],
              hearing_title: hearing_data["topic"],

              # document information
              bill_id: hearing_doc["bill_id"],
              description: hearing_doc["description"],
              type: hearing_doc["type"],
              # type_name: hearing_doc["type_name"],
              version_code: hearing_doc["version_code"],
              bioguide_id: hearing_doc["bioguide_id"],
              publish_date: hearing_datetime,
              urls: urls
              # would like to add full text 

            }

            collection = "congressional_documents"
            ## save to elastic search
            #  from utils use def self.es_store!(collection, id, document)
            Utils.es_store! collection, id, document
            # unless details = Utils.es_store! collection, id, document
            #   warnings << {message: "Error while saving #{url}, in congressional hearing documents skipping article", url: url}
            #   next
            # end

            end
          end
        end

        if (witnesses != nil)
          puts "found witness docs" 
          # process
        end
    end
  end
end
