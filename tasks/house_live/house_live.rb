class HouseLive
  
  def self.run(options = {})
    script = File.join File.dirname(__FILE__), "grab_videos.py"
    system "python #{script} #{options[:config][:mongoid]['host']} #{options[:config][:mongoid]['database']} #{options[:args].join ' '}"
  end
  
end