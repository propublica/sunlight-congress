require 'sinatra'
require 'mongoid'

def config
  @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
end

configure do
  Mongoid.configure {|c| c.from_hash config[:mongoid]}
end

Dir.glob(File.join(File.dirname(__FILE__), "../models/*.rb")) {|filename| load filename}

# special fields used by the system, cannot be used on a model (on the top level)
def magic_fields
  [:apikey, :sections, :order, :sort, :captures, :page, :per_page, :callback]
end