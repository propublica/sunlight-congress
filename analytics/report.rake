namespace :analytics do

  desc "Send analytics to the central API analytics department."
  task :report => :environment do
    begin
      require './analytics/sunlight_services'
    
      # default to yesterday
      day = ENV['day'] || (Time.now.midnight - 1.day).strftime("%Y-%m-%d")
      test = !ENV['test'].nil?
      
      start_time = Time.now
      start = Time.parse day
      finish = start + 1.day

      # baked into HitReport
      reports = HitReport.for_day day
      
      api_name = config[:services][:api_name]
      shared_secret = config[:services][:shared_secret]
      
      if test
        puts "\nWould report for #{day}:\n\n#{reports.inspect}\n\nTotal hits: #{reports.sum {|r| r['count']}}\n\n"
      else
        reports.each do |report|
          begin
            SunlightServices.report(report['key'], report['method'], report['count'].to_i, day, api_name, shared_secret)
          rescue Exception => exception
            report = Report.failure 'Analytics', "Problem filing a report, error and report data attached", {error_message: exception.message, :backtrace => exception.backtrace, :report => report, :day => day}
            puts report
            email report
          end
        end
        
        report = Report.success 'Analytics', "Filed #{reports.size} report(s) for #{day}.", {elapsed_time: (Time.now - start_time)}
        puts report
      end
      
      
    # general exception catching for reporting
    rescue Exception => ex
      report = Report.failure 'Analytics', "Exception while reporting analytics, message and backtrace attached", {exception: {'message' => ex.message, 'type' => ex.class.to_s, 'backtrace' => ex.backtrace}}
      puts report
      email report
      
    end
  end
end