require './test/test_helper'

class BasicTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include TestHelper::Methods
  include FactoryGirl::Syntax::Methods

  def test_status
    get "/"
    assert_response 200

    assert_match /application\/json/, last_response.headers['Content-Type']
    assert_match /report_bugs/, last_response.body
  end

  def test_mongo

  end

  def test_elasticsearch
    # Searchable.client
  end

end