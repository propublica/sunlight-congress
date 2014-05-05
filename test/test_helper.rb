ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'test/unit'

require 'bundler/setup'
require 'rack/test'

require './congress'
require 'timecop'

set :environment, :test

module TestHelper

  module Methods

    # Test::Unit hooks

    def setup
      Timecop.freeze

      # initialize Elasticsearch test index
      if Searchable.client.indices.exists(index: Searchable.index)
        Searchable.client.indices.delete index: Searchable.index
      end

      Searchable.client.indices.create index: Searchable.index
    end

    def teardown
      Mongoid.models.each &:delete_all

      # clear Elasticsearch test index
      # Searchable.client.indices.delete index: Searchable.index

      Timecop.return
    end


    # Sinatra helpers

    def app
      Sinatra::Application
    end

    def redirect_path
      if last_response.headers['Location']
        last_response.headers['Location'].sub(/http:\/\/example.org/, '')
      else
        nil
      end
    end

    def assert_response(status, message = nil)
      assert_equal status, last_response.status, (message || last_response.body)
    end

    def assert_json
      assert_match /application\/json/, last_response.headers['Content-Type']
    end

    def assert_redirect(path)
      assert_response 302
      assert_equal path, redirect_path
    end

  end
end