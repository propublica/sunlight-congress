ENV['RACK_ENV'] = "development"

require 'rubygems'
require 'bundler/setup'


# App-level logging is CURRENTLY DISABLED IN PRODUCTION.
#
# BEFORE EVER ENABLING IN PRODUCTION:
#
# Do the logging HERE -- NOT by enabling :logging in Sinatra,
# and NOT by turning on logging in a unicorn.rb.
#
# Log by uncommenting the lines below and updating the log path.
#
# PRESERVE THE FILTERING LOGIC.
#
# This will ensure that latitude and longitude are not written out
# to disk, as we promise to users in our API documentation.
#
# Bear in mind, application-level logging is slow and voluminous,
# and we have already implemented a similar filter at the nginx-level.
#
# Thus, logging at the application-level is currently NOT desired.
#
#
# logger = Logger.new("/path/to/unicorn.log")
# logger.instance_eval do
#   def write(msg)
#     # scrub latitude and longitude params from app-level logs
#     msg.gsub! /(?:lat|long)itude=[\d\.\-]+/, 'XXX=XXX'
#     self.send(:<<, msg)
#   end
# end
# use Rack::CommonLogger, logger


require './congress'
run Sinatra::Application