require 'oj'
require 'mongoid'
require 'tzinfo'
require 'rubberband'
require 'cgi'
require 'hmac-sha1'
require 'net/http'

require 'sinatra'
disable :protection
disable :logging

require './api/api'
require './api/queryable'
require './api/searchable'

Dir.glob('models/*.rb').each {|f| load f}

class Environment
  def self.config
    @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
  end
end

configure do
  Mongoid.load! File.join(File.dirname(__FILE__), "mongoid.yml")

  Api::Searchable.configure_clients!

  Time::DATE_FORMATS.merge!(:default => Proc.new {|t| t.xmlschema})
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"
  Oj.default_options = {mode: :compat, time_format: :ruby}
end