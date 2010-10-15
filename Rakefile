Dir.glob('tasks/*.rb').each do |file|
  name = File.basename file, File.extname(file)
  
  namespace :task do
    task name.to_sym => :environment do
      run_task name
    end
  end
end

task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require 'environment'
  
  require 'tasks'
end

def run_task(name)
  load "tasks/#{name}.rb"
  task_name = name.camelize
  task = task_name.constantize
  
  start = Time.now
  
  if ENV['just_run'].to_i > 0
    task.run
  else
    begin
      task.run
    rescue Exception => ex
      Report.failure task_name, "Exception running #{name}, message and backtrace attached", {:elapsed_time => Time.now - start, :exception => {:error_message => ex.message, :type => ex.class.to_s}}
    else
      Report.complete task_name, "Completed running #{name}", {:elapsed_time => Time.now - start}
    end
  end
end