#!/usr/bin/env ruby

require 'environment'
configure(:development) {require 'sinatra/reloader'}


get '/' do
  Legislator.first.bioguide_id
end