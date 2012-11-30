task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require './config/environment'
end

desc "Load a fake api key into the db"
task :api_key => :environment do
  key = ENV['key'] || "development"
  email = ENV['email'] || "#{key}@example.com"
  
  if ApiKey.where(key: key).first.nil?
    ApiKey.create! status: "A", email: email, key: key
    puts "Created '#{key}' API key under email #{email}"
  else
    puts "'#{key}' API key already exists"
  end
end

desc "Run through each model and create all indexes" 
task :create_indexes => :environment do
  begin
    models = Dir.glob('models/*.rb').map do |file|
      File.basename(file, File.extname(file)).camelize.constantize
    end
    
    models.each do |model| 
      if model.respond_to? :create_indexes
        model.create_indexes 
        puts "Created indexes for #{model}"
      else
        puts "Skipping #{model}, not a Mongoid model"
      end
    end
  rescue Exception => exception
    Email.report Report.exception("Indexes", "Exception creating indexes", exception)
    puts "Error creating indexes, emailed report."
  end
end

desc "Set the crontab in place for this environment"
task :set_crontab => :environment do
  environment = ENV['environment']
  current_path = ENV['current_path']
  
  if environment.blank? or current_path.blank?
    puts "No environment or current path given, exiting."
    exit
  end
  
  if system("cat #{current_path}/config/cron/#{environment}.crontab | crontab")
    puts "Successfully overwrote crontab."
  else
    Email.message "Crontab overwriting failed on deploy."
    puts "Unsuccessful in overwriting crontab, emailed report."
  end
end

desc "Disable/clear the crontab for this environment"
task :disable_crontab => :environment do
  if system("echo | crontab")
    puts "Successfully disabled crontab."
  else
    Email.message "Somehow failed at disabling crontab."
    puts "Unsuccessful (somehow) at disabling crontab, emailed report."
  end
end


# for each folder in tasks, generate a rake task
Dir.glob('tasks/*/').each do |file|
  name = File.basename file
  
  desc "__________________________________"
  namespace :task do
    task name.to_sym => :environment do
      run_task name
    end
  end
end


def run_task(name)  
  task_name = name.camelize
  start = Time.now
  
  begin
    if File.exist? "tasks/#{name}/#{name}.rb"
      run_ruby name
    elsif File.exist? "tasks/#{name}/#{name}.py"
      run_python name
    end
    
  rescue Exception => ex
    if ENV['raise']
      raise ex
    else
      Report.exception task_name, "Exception running #{name}", ex, {elapsed: (Time.now - start)}
    end
    
  else
    Report.complete task_name, "Completed running #{name}", {elapsed: (Time.now - start)}
  end
  
  Report.unread.where(source: task_name).all.each do |report|
    puts report
    puts report.exception_message if report.exception?
    Email.report report if report.failure? or report.warning? or report.note?
    report.mark_read!
  end

end

def run_ruby(name)
  load "./tasks/#{name}/#{name}.rb"
  
  options = {config: Environment.config}
  ARGV[1..-1].each do |arg|
    key, value = arg.split '='
    if key.present? and value.present?
      options[key.downcase.to_sym] = value
    end
  end
  
  name.camelize.constantize.run options
end

def run_python(name)
  system "python tasks/runner.py #{name} #{ARGV[1..-1].join ' '}"
end

namespace :analytics do

  desc "Send analytics to the central API analytics department."
  task :report => :environment do
    begin
      
      # default to yesterday
      day = ENV['day'] || (Time.now.midnight - 1.day).strftime("%Y-%m-%d")
      test = !ENV['test'].nil?
      
      start_time = Time.now
      start = Time.parse day
      finish = start + 1.day

      # baked into HitReport
      reports = HitReport.for_day day
      
      api_name = Environment.config[:services][:api_name]
      shared_secret = Environment.config[:services][:shared_secret]
      
      if test
        puts "\nWould report for #{day}:\n\n#{reports.inspect}\n\nTotal hits: #{reports.sum {|r| r['count']}}\n\n"
      else
        reports.each do |report|
          begin
            SunlightServices.report(report['key'], report['method'], report['count'].to_i, day, api_name, shared_secret)
          rescue Exception => exception
            report = Report.exception 'Analytics', "Exception filing a report", exception
            puts report
            Email.report report
          end
        end
        
        report = Report.success 'Analytics', "Filed #{reports.size} report(s) for #{day}.", {elapsed: (Time.now - start_time)}
        puts report
      end
      
      
    # general exception catching for reporting
    rescue Exception => exception
      report = Report.exception 'Analytics', "Exception reporting analytics", exception
      puts report
      Email.report report

    end
  end
end

namespace :elasticsearch do
  task :init => :environment do
    single = ENV['mapping'] || ENV['only'] || nil
    force = ENV['force'] || ENV['delete'] || false

    mappings = single ? [single] : Dir.glob('config/elasticsearch/mappings/*.json').map {|dir| File.basename dir, File.extname(dir)}

    host = Environment.config['elastic_search']['host']
    port = Environment.config['elastic_search']['port']
    index = Environment.config['elastic_search']['index']
    index_url = "http://#{host}:#{port}/#{index}/"

    system "curl -XPUT '#{index_url}'"
    puts
    puts "Ensured index exists" 
    puts

    mappings.each do |mapping|
      if force
        system "curl -XDELETE '#{index_url}/#{mapping}/_mapping'"
        puts
        puts "Deleted #{mapping}"
        puts
      end

      system "curl -XPUT '#{index_url}/#{mapping}/_mapping' -d @config/elasticsearch/mappings/#{mapping}.json"
      puts
      puts "Created #{mapping}"
      puts
    end
  end
end