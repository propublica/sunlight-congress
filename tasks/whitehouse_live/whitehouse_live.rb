class WhitehouseLive
  
  def self.run(options = {})
    script = File.join File.dirname(__FILE__), "get_live_videos.py"
    system "python #{script} #{options[:config][:mongoid]['host']} #{options[:config][:mongoid]['database']} #{options[:args].join ' '}"
  end
end
