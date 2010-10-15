require 'environment'

class Report
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :status
  field :source
  field :message
  field :elapsed_time, :type => Float
  field :attached, :type => Hash
  
  index :status
  index :source
  
  def self.file(status, source, message, rest = {})
    report = Report.new({:source => source, :status => status, :message => message}.merge(rest))
    
    report.save
    puts report.to_s
    # send_email report if ['FAILURE', 'WARNING'].include?(status.to_s)
    
    report
  end
  
  def self.success(source, message, objects = {})
    file 'SUCCESS', source, message, objects
  end
  
  def self.failure(source, message, objects = {})
    file 'FAILURE', source, message, objects
  end
  
  def self.warning(source, message, objects = {})
    file 'WARNING', source, message, objects
  end
  
  def self.complete(source, message, objects = {})
    file 'COMPLETE', source, message, objects
  end
  
#   def self.latest(model, size = 1)
#     reports = Report.all :conditions => {:source => model.to_s}, :order => "created_at DESC", :limit => size
#     size > 1 ? reports : reports.first
#   end
  
#   def self.send_email(report)
#     if email[:to] and email[:to].any?
#       Pony.mail email.merge(:subject => report.to_s, :body => report.attributes.inspect)
#     end
#   end
  
#   def self.email=(details)
#     @email = details
#   end
#   
#   def self.email
#     @email
#   end
  
  def to_s
    "[#{status}] #{source}#{elapsed_time ? " [#{to_minutes elapsed_time.to_i}]" : ""}\n    #{message}"
  end
  
  def to_minutes(seconds)
    min = seconds / 60
    sec = seconds % 60
    "#{min > 0 ? "#{min}m," : ""}#{sec}s"
  end
end