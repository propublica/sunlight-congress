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
  
  begin
    task.run :config => config
    
  rescue Exception => ex
    Report.failure task_name, "Exception running #{name}, message and backtrace attached", {:elapsed_time => Time.now - start, :exception => {'message' => ex.message, 'type' => ex.class.to_s, 'backtrace' => ex.backtrace}}
    
  else
    Report.complete task_name, "Completed running #{name}", {:elapsed_time => Time.now - start}
  end
  
end

Dir.glob('tasks/*.rb').each do |file|
  name = File.basename file, File.extname(file)
  
  namespace :task do
    task name.to_sym => :environment do
      run_task name
    end
  end
end