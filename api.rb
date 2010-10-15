#!/usr/bin/env ruby

require 'environment'

get '/' do
  # Legislator.first.bioguide_id
  Legislator.count.to_s
end