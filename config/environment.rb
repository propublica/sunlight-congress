require 'oj'
require 'sinatra'
require 'mongoid'
require 'tzinfo'
require 'rubberband'

require './api/api'
require './api/queryable'
require './api/searchable'

Dir.glob('models/*.rb').each do |filename|
  load filename
  model_name = File.basename filename, File.extname(filename)
end

class Environment
  def self.config
    @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
  end
end

configure do
  # configure mongodb client
  Mongoid.load! File.join(File.dirname(__FILE__), "mongoid.yml")
  
  Api::Searchable.configure_clients!
  
  # insist on my API-wide timestamp format
  Time::DATE_FORMATS.merge!(:default => Proc.new {|t| t.xmlschema})

  # This is for when people search by date (with no time), or a time that omits the time zone
  # We will assume users mean Eastern time, which is where Congress is.
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"

  # insist on using the time format I set as the Ruby default,
  # even in dependent libraries that use MultiJSON (e.g. rubberband)
  Oj.default_options = {mode: :compat, time_format: :ruby}
end