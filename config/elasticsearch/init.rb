#!/usr/bin/env ruby

port = ARGV[0] || 9200

Dir.glob('config/elasticsearch/mappings/*.json').map {|dir| File.basename dir, File.extname(dir)}.each do |mapping|
  system "curl -XPUT 'http://localhost:#{port}/rtc_#{mapping}/'"
  system "curl -XPUT 'http://localhost:#{port}/rtc_#{mapping}/#{mapping}/_mapping' -d @config/elasticsearch/mappings/#{mapping}.json"
end