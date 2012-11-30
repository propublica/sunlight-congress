require 'oj'
require 'mongoid'
require 'tzinfo'
require 'rubberband'
require 'pony'

require 'sinatra'
disable :protection
disable :logging

require './api/api'
require './api/queryable'
require './api/searchable'
require './api/citable'
require './tasks/utils'
Dir.glob('models/*.rb').each {|f| load f}

class Environment
  def self.config
    @config ||= YAML.load_file File.join(File.dirname(__FILE__), "config.yml")
  end

  def self.check_key?
    !(config[:debug] and config[:debug][:ignore_apikey])
  end
end

configure do
  Mongoid.load! File.join(File.dirname(__FILE__), "mongoid.yml")

  Searchable.configure_clients!

  Time::DATE_FORMATS.merge!(:default => Proc.new {|t| t.xmlschema})
  Time.zone = ActiveSupport::TimeZone.find_tzinfo "America/New_York"
  Oj.default_options = {mode: :compat, time_format: :ruby}
end


# utilities for sending email
class Email
  
  def self.message(message)
    send_email message, message, config[:recipients][:admin]
  end

  def self.report(report)
    subject = "[#{report.status}] #{report.source} | #{report.message}"

    body = "#{report.id}\n\n#{report.message}"

    if report['attached']['exception']
      body += "\n\n#{exception_message report}"
    end
    
    attrs = report.attributes.dup
    
    [:status, :created_at, :updated_at, :_id, :message, :exception, :read, :source].each {|key| attrs.delete key.to_s}

    attrs['attached'].delete 'exception'
    attrs.delete('attached') if attrs['attached'].empty?
    body += "\n\n#{JSON.pretty_generate attrs}" if attrs.any?

    send_email subject, body, email_recipients_for(report)
  end

  # admin + any task-specific owners
  def self.email_recipients_for(report)
    task = report.source.underscore.to_sym
    
    recipients = Environment.config[:recipients][:admin].dup
    recipients += task_owners if task_owners = Environment.config[:recipients][task]
    recipients.uniq
  end

  def self.exception_message(report)
    msg = "#{report[:attached]['exception']['type']}: #{report[:attached]['exception']['message']}\n\n" 
    
    if report[:attached]['exception']['backtrace'].respond_to?(:each)
      report[:attached]['exception']['backtrace'].each {|line| msg += "#{line}\n"}
    end
    
    msg
  end

  def self.send_email(subject, body, to)
    return unless Environment.config[:email][:from]

    Pony.mail Environment.config[:email].merge(
      subject: subject, 
      body: body, 
      to: to
    )
  rescue Errno::ECONNREFUSED
    puts "Couldn't email report, connection refused! Check system settings."
  end
end