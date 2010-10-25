require 'sinatra'
require 'mongoid'

def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
end

configure do
  Mongoid.configure {|c| c.from_hash config[:mongoid]}
end

Dir.glob(File.join(File.dirname(__FILE__), "../models/*.rb")) {|filename| load filename}