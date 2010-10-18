task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require 'config/environment'
  
  require 'tasks/report'
end

# for each folder in tasks, generate a rake task
Dir.glob('tasks/*/').each do |file|
  name = File.basename file
  
  namespace :task do
    task name.to_sym => :environment do
      run_task name
    end
  end
end


def run_task(name)
  require 'pony'
  
  load "tasks/#{name}/#{name}.rb"
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
  
  # go through any reports filed from the task, and email about any failures or warnings
  Report.unread.where(:source => task_name).all.each do |report|
    if report.failure? or report.warning?
      begin
        email report
      rescue Exception => ex
        puts "Error emailing a report! Will try again on next run"
      else
        report.mark_read!
      end
    else
      report.mark_read!
    end
  end

end

def email(report)
  if config[:email][:to] and config[:email][:to].any?
    Pony.mail config[:email].merge(:subject => report.to_s, :body => report.attributes.inspect)
  end
end
