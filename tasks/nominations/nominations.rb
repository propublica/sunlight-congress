# reads in nomination data from the unitedstates/congress project
#   congress: Limit to a particular congress.
#   nomination_id: Limit to a particular nomination. (e.g. PN47-113)
#   limit: Limit to a number of nominations total.


require "./tasks/bills/bills"

class Nominations

  def self.run(options = {})
    congress = options[:congress] ? options[:congress].to_i : Utils.current_congress

    count = 0
    failures = []
    bad_committees = [] # mismatched committee names
    committee_cache = {}

    unless File.exists?("data/unitedstates/congress/#{congress}/nominations")
      Report.failure self, "Data not available on disk for the requested Congress."
      return
    end

    if options[:nomination_id]
      nomination_ids = [options[:nomination_id]]
    else
      paths = Dir.glob("data/unitedstates/congress/#{congress}/nominations/*")
      numbers = paths.map {|path| File.basename(path).to_s}.sort
      nomination_ids = numbers.map {|number| "PN#{number}-#{congress}"}
      if options[:limit]
        nomination_ids = nomination_ids.first options[:limit].to_i
      end
    end

    nomination_ids.each do |nomination_id|
      nomination = Nomination.find_or_initialize_by nomination_id: nomination_id
      number, congress = Utils.nomination_fields_from nomination_id

      path = "data/unitedstates/congress/#{congress}/nominations/#{number}/data.json"
      doc = Oj.load open(path)

      actions = Bills.actions_for doc['actions'], committee_cache
      last_action = actions.any? ? actions.last : nil
      last_action_at = actions.any? ? actions.last['acted_at'] : received_on

      attributes = {
        congress: congress.to_i,
        number: number.to_s,

        nominees: doc["nominees"],
        organization: doc["organization"],

        received_on: doc["received_on"],
        committee_ids: doc["referred_to"],

        actions: actions,
        last_action: last_action,
        last_action_at: last_action_at
      }

      nomination.attributes = attributes
      begin
        nomination.save!
        puts "[#{nomination_id}] Saved" if options[:debug]

        count += 1
      rescue Exception => ex
        failures << Report.exception_to_hash(ex)
      end
    end

    if failures.any?
      Report.failure self, "Failed to save #{failures.size} nominations, attached.", failures: failures
    end

    Report.success self, "Saved #{count} nominations for congress ##{congress}."
  end

end
