task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require './config/environment'
  require 'pony'
end

# does not hinge on the environment, test_helper loads it itself
task :default => :test
task :test do
  responses = Dir.glob("test/**/*_test.rb").map do |file|
    puts "\nRunning #{file}:\n"
    system "ruby #{file}"
  end
  
  if responses.any? {|code| code == false}
    puts "\nFAILED\n"
    exit -1
  else
    puts "\nSUCCESS\n"
    exit 0
  end
end

desc "Load a fake api key into the db"
task :api_key => :environment do
  key = ENV['key'] || "development"
  email = ENV['email'] || "#{key}@example.com"
  
  if ApiKey.where(:key => key).first.nil?
    ApiKey.create! :status => "A", :email => email, :key => key
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
  rescue Exception => ex
    email "Exception creating indexes, message and backtrace attached", {'message' => ex.message, 'type' => ex.class.to_s, 'backtrace' => ex.backtrace}
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
    email "Crontab overwriting failed on deploy."
    puts "Unsuccessful in overwriting crontab, emailed report."
  end
end

desc "Disable/clear the crontab for this environment"
task :disable_crontab => :environment do
  if system("echo | crontab")
    puts "Successfully disabled crontab."
  else
    email "Somehow failed at disabling crontab."
    puts "Unsuccessful (somehow) at disabling crontab, emailed report."
  end
end


# for each folder in tasks, generate a rake task
Dir.glob('tasks/*/').each do |file|
  name = File.basename file
  
  desc "runs #{name} task"
  namespace :task do
    task name.to_sym => :environment do
      run_task name
    end
  end
end


def run_task(name)
  require './tasks/utils'
  
  task_name = name.camelize
  
  start = Time.now
  
  begin
    if File.exist? "tasks/#{name}/#{name}.rb"
      run_ruby name
    elsif File.exist? "tasks/#{name}/#{name}.py"
      run_python name
    else
      raise Exception.new "Couldn't locate task file"
    end
    
  rescue Exception => ex
    if ENV['raise'] == "true"
      raise ex
    else
      Report.failure task_name, "Exception running #{name}, message and backtrace attached", {:elapsed_time => Time.now - start, :exception => {'message' => ex.message, 'type' => ex.class.to_s, 'backtrace' => ex.backtrace}}
    end
    
  else
    complete = Report.complete task_name, "Completed running #{name}", {elapsed_time: (Time.now - start)}
    puts complete
  end
  
  # go through any reports filed from the task, and email about any failures or warnings
  Report.unread.where(:source => task_name).all.each do |report|
    puts report
    email report if report.failure? or report.warning? or report.note?
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

def email(report, exception = nil)
  if Environment.config[:email][:to] and Environment.config[:email][:to].any?
    begin
      if report.is_a?(Report)
        Pony.mail Environment.config[:email].merge(:subject => email_subject(report), :body => email_body(report), :to => email_recipients_for(report))
      else
        Pony.mail Environment.config[:email].merge(:subject => report, :body => (exception ? exception_message(exception) : report))
      end
    rescue Errno::ECONNREFUSED
      puts "Couldn't email report, connection refused! Check system settings."
    end
  end
end

def email_recipients_for(report)
  task = report.source.underscore.to_sym
  
  recipients = Environment.config[:email][:to].dup # always begin with master recipients
  
  if Environment.config[:task_owners] and Environment.config[:task_owners][task]
    recipients += Environment.config[:task_owners][task]
  end
  
  recipients.uniq
end

def email_subject(report)
  "[#{report.status}] #{report.source} | #{report.message}"
end

def email_body(report)
  msg = ""
  msg += exception_message(report[:exception]) if report[:exception]
  
  attrs = report.attributes.dup
  [:status, :created_at, :updated_at, :_id, :message, :exception, :read, :source].each {|key| attrs.delete key.to_s}
  
  msg += JSON.pretty_generate attrs
  msg
end

def exception_message(exception)
  msg = ""
  msg += "#{exception['type']}: #{exception['message']}" 
  msg += "\n\n"
  
  if exception['backtrace'] and exception['backtrace'].respond_to?(:each)
    exception['backtrace'].each {|line| msg += "#{line}\n"}
    msg += "\n\n"
  end
  
  msg
end

namespace :analytics do

  desc "Send analytics to the central API analytics department."
  task report: :environment do
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

namespace :elasticsearch do
  task init: :environment do
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