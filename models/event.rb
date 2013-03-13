# generic class used to record things
class Event
  include Mongoid::Document
  include Mongoid::Timestamps

  index event_type: 1

  def self.new_summaries!(data)
    create! event_type: "new_summaries", data: data, today: Time.zone.now.strftime("%Y-%m-%d")
  end
end