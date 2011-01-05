namespace :analytics do

  desc "Send analytics to the central API analytics department."
  task :report => :environment do
    begin
      require 'analytics/hits'
      require 'analytics/sunlight_services'
      require 'tasks/report'
    
      # default to yesterday
      day = ENV['day'] || (Time.now.midnight - 1.day).strftime("%Y-%m-%d")
      test = !ENV['test'].nil?
      
      start_time = Time.now
      
      start = Time.parse day
      finish = start + 1.day
      conditions = {:created_at => {"$gte" => start, "$lt" => finish}}
      
      reports = []
      
      # get down to the driver level for the iteration
      hits = Mongoid.database.collection :hits
      
      keys = hits.distinct :key, conditions
      keys.each do |key|
        methods = hits.distinct :method, conditions.merge(:key => key)
        methods.each do |method|
          count = Hit.where(conditions.merge(:key => key, :method => method)).count
          reports << {:key => key, :method => method, :count => count}
        end
      end
      
      sum_count = reports.map {|r| r[:count]}.sum
      hit_count = Hit.where(conditions).count
      if sum_count == hit_count
        api_name = config[:services][:api_name]
        shared_secret = config[:services][:shared_secret]
        
        reports.each do |report|
          begin
            SunlightServices.report(report[:key], report[:method], report[:count], day, api_name, shared_secret) unless test
          rescue Exception => exception
            report = Report.failure 'Analytics', "Problem filing a report, error and report data attached", {:error_message => exception.message, :backtrace => exception.backtrace, :report => report, :day => day}
            puts report
            email report
          end
        end
        
        if test
          puts "\nWould report for #{day}:\n\n#{reports.inspect}\n\nTotal hits: #{reports.sum {|r| r[:count]}}\n\n"
        else
          report = Report.success 'Analytics', "Filed #{reports.size} report(s) for #{day}.", {:elapsed_time => (Time.now - start_time)}
          puts report
        end
      
      else
        report = Report.failure 'Analytics', "Sanity check failed: error calculating hit reports. Reports attached.", {:reports => reports, :day => day}
        puts report
        email report
      end
      
    # general exception catching for reporting
    rescue Exception => ex
      report = Report.failure 'Analytics', "Exception while reporting analytics, message and backtrace attached", {:exception => {'message' => ex.message, 'type' => ex.class.to_s, 'backtrace' => ex.backtrace}}
      puts report
      email report
      
    end
  end
end