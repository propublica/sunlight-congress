require 'sinatra'
require 'mongoid'

def config
  @config ||= YAML.load_file 'config/config.yml'
end

configure do
  Mongoid.configure {|c| c.from_hash config[:mongoid]}
end

Dir.glob('models/*.rb') {|filename| load filename}