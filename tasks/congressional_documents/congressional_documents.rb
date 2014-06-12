# encoding: utf-8
require 'us-documents'

class CongressionalDocuments
  def self.run(options = {})
    # Uses @unitedstates house hearing scraper documents to get hearing documents
    # Planning to get additional documents from FDsys and perhaps Senate Committees 

    # meeting documents
    path = "data/unitedstates/congress"
    house_json = File.read "#{path}/committee_meetings_house.json"

    house_data = Oj.load house_json
    house_data.each do |hearing_data|
      if (hearing_data != nil)
        if (hearing_data["meeting_documents"] == nil && hearing_data["witnesses"] == nil)
          puts "no doc information"
          next #skip records without documents
        end

        chamber = hearing_data["chamber"]
        house_event_id = hearing_data["house_event_id"]
        hearing_type_code = hearing_data["house_meeting_type"]
        hearing_title = hearing_data["topic"]

        # extract docs from witness and meeting documents
        witnesses = hearing_data["witnesses"]
        meeting_documents = hearing_data["meeting_documents"]

        if (meeting_documents != nil)
          hearing_data["meeting_documents"].each do |hearing_doc| 

            if (hearing_doc["publish_date"] != nil)
              hearing_datetime = Time.zone.parse(hearing_doc["publish_date"]).utc
            else
              hearing_datetime = nil
            end
            text = nil
            urls = Array.new 
            if hearing_doc["urls"]
              url_base = File.basename(hearing_doc["urls"][0]["url"])
              urls = []
              hearing_doc["urls"].each do |u|
                url = {}
                url["url"] = u["url"]
                url["permalink"] = "placeholder" #{}"unitedstates/congress/committee/meetings/house/#{url_base}"
                urls.push(url)
                if u["file_found"] == true
                  # extract text
                  text_name = url_base.sub ".pdf", ".txt"
                  text_file = "data/unitedstates/congress/committee/meetings/house/#{house_event_id}/#{text_name}"
                  text = File.read text_file
                else
                  text = nil
                end
              end
            else
              # sometimes there is no url
              next
            end
            
            id = "house-#{house_event_id}-#{url_base}"
            puts text
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
              bill_id: hearing_doc["bill_id"],
              description: hearing_doc["description"],
              type: hearing_doc["type"],
              type_name: hearing_doc["type_name"],
              version_code: hearing_doc["version_code"],
              bioguide_id: hearing_doc["bioguide_id"],
              publish_date: hearing_datetime,
              urls: urls,
              text: text,
            }

            # save to elastic search
            collection = "congressional_documents"
            Utils.es_store! collection, id, document

            end
          end
        end

        if (witnesses != nil) 
          hearing_data["witnesses"].each do |witness| 


            witness["documents"].each do |witness_doc|
              urls = []
              url_base = File.basename(witness_doc["urls"][0]["url"])
              
              witness_doc["urls"].each do |u|
                if u["file_found"] == true
                  url = {}
                  url["url"] = u["url"]
                  url["permalink"] = "placeholder" #{}"unitedstates/congress/committee/meetings/house/#{url_base}"
                  urls.push(url)
                  # add link to our link
                else
                  text = nil
                end
              end

              if (witness_doc["publish_date"] != nil)
                hearing_datetime = Time.zone.parse(witness_doc["publish_date"]).utc
              else
                hearing_datetime = nil
              end

              # extract text
              text_name = url_base.sub ".pdf", ".txt"
              text_file = "data/unitedstates/congress/committee/meetings/house/#{house_event_id}/#{text_name}"
              text = File.read text_file

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
                description: witness_doc["description"],
                type: witness_doc["type"],
                type_name: witness_doc["type_name"],
                type_name: witness_doc["type_name"],
                bioguide_id: witness_doc["bioguide_id"],
                publish_date: hearing_datetime,
                urls: urls,
                text: text,
              }

              # save to elastic search
              collection = "congressional_documents"
              Utils.es_store! collection, id, document

            end
          end 
        end
    end
    # add boto r sync the folders
  end
end
