class WhitehouseArchive
  
  def self.run(options = {})
    script = File.join File.dirname(__FILE__), "get_rss_archive.py"
    system "python #{script} #{options[:config][:mongoid]['host']} #{options[:config][:mongoid]['database']} #{options[:args].join ' '}"
  end
end
