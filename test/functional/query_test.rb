require './test/test_helper'

class QueryTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods

  def test_fields_with_dollar_signs_are_gracefully_ignored
    vote = Vote.create!(
      roll_id: "h509-2013",
      voters: {
        "L000551" => {
          vote: "Yea",
          voter: {bioguide_id: "L000551"}
        }
      }
    )

    get "/votes", {
      roll_id: "h509-2013",

      # doesn't apply here, but was crashing the app in production once
      fields: "roll_id,voters.$.voter_id"
    }

    assert_response 200
    assert_json

    assert_match /h509-2013/, last_response.body
  end
end