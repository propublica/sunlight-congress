#!/usr/bin/env ruby

Dir.glob('config/elasticsearch/mappings/*.json').map {|dir| File.basename dir, File.extname(dir)}.each do |mapping|
  system "curl -XPUT 'http://localhost:9200/rtc_#{mapping}/'"
  system "curl -XPUT 'http://localhost:9200/rtc_#{mapping}/#{mapping}/_mapping' -d @config/elasticsearch/mappings/#{mapping}.json"
end