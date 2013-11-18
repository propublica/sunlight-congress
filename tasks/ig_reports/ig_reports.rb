require 'docsplit'

class IgReports

  # Loads inspector general reports. Expects reports and metadata
  # on disk, as created by the unitedstates/inspectors-general project.
  #
  # Defaults to the current year's reports.
  #
  # options:
  #   years: fetch specific years' reports. defaults to current year.
  #      comma-separate for multiple years, e.g. "2012,2013"
  #   inspectors: fetch specific IGs' reports. defaults to all.
  #      comma-separate for multiple inspectors, e.g. "usps,nsa"

  def self.run(options = {})
    if options[:years].present?
      years = options[:years].split(",").map(&:strip).map &:strip
    else
      years = [Time.now.year]
    end

    if options[:inspectors].present?
      inspectors = options[:inspectors].split(",").map &:strip
    else
      inspectors = []
    end

    unless File.exists?("data/unitedstates/inspectors-general")
      Report.failure self, "IG report data not available on disk."
      return
    end

    count = 0
    failures = []
    warnings = []
    batcher = [] # used to persist a batch indexing container

    years.each do |year|
      all_inspectors = Dir.glob("data/unitedstates/inspectors-general/*").map {|path| File.basename path}
      all_inspectors = (all_inspectors & inspectors) if inspectors.any?
      all_inspectors.each do |inspector|

        report_ids = Dir.glob("data/unitedstates/inspectors-general/#{inspector}/#{year}/*").map {|path| File.basename path}
        report_ids.each do |report_id|

          Dir.glob("data/unitedstates/inspectors-general/#{inspector}/#{year}/#{report_id}") do |path|
            document_id = "ig_report-#{inspector}-#{year}-#{report_id}"
            report = Document.find_or_initialize_by document_id: document_id

            begin
              json = File.read "#{path}/report.json"
              text = File.read "#{path}/report.txt"
            rescue Exception => ex
              failures << {msg: "Error reading JSON and text from disk.", inspector: inspector, year: year, report_id: report_id}
              next
            end

            # copy the bulk data, except for local file paths
            report_data = Oj.load json
            ['report_path', 'text_path'].each {|f| report_data.delete f}

            # standard Congress API 'document' fields
            attributes = {
              document_id: document_id,
              document_type: "ig_report",
              document_type_name: "Inspector General Report",

              title: report_data['title'],

              published_on: report_data['published_on'],
              posted_at: Utils.utc_parse(report_data['published_on']),

              url: report_data['url'],
              source_url: report_data['url'],

              ig_report: report_data
            }

            # extract citations
            unless attributes[:citation_ids] = Utils.citations_for(report, text, citation_cache(inspector, year, report_id), options)
              warnings << {message: "Failed to extract citations from #{document_id}"}
              attributes[:citation_ids] = []
            end

            # index document and text in ElasticSearch
            es_document = attributes.merge(text: text)
            Utils.es_batch! 'documents', document_id, es_document, batcher, options

            # index document in MongoDB
            report.attributes = attributes
            report.save!

            puts "[#{document_id}] Successfully saved report"
            count += 1
          end
        end
      end
    end

    if failures.any?
      Report.failure self, "Failed to process #{failures.size} reports", {failures: failures}
    end

    if warnings.any?
      Report.warning self, "Failed to process text for #{warnings.size} reports", {warnings: warnings}
    end

    Report.success self, "Saved #{count} IG reports."
  end

  def self.citation_cache(inspector, year, report_id)
    "data/citations/ig_reports/#{inspector}/#{year}/#{report_id}/citations.json"
  end

end