class Report
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :status
  field :source
  field :message
  field :attached, type: Hash, default: {}
  
  field :read, type: Boolean, default: false
  
  index status: 1
  index source: 1
  index read: 1
  index created_at: 1
  
  scope :unread, where(read: false)
  scope :latest, lambda {|status| desc(:created_at).where(status: status.upcase)}
  
  def self.file(status, source, message, attached = {})
    Report.create! source: source.to_s, status: status, message: message, attached: attached
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
  
  def self.note(source, message, objects = {})
    file 'NOTE', source, message, objects
  end
  
  def self.complete(source, message, objects = {})
    file 'COMPLETE', source, message, objects.merge(read: true)
  end

  def self.exception(source, message, exception, objects = {})
    file 'FAILURE', source, message, {
      'exception' => exception_to_hash(exception)
      }.merge(objects)
  end

  def self.exception_to_hash(exception)
    {
      'backtrace' => exception.backtrace, 
      'message' => exception.message, 
      'type' => exception.class.to_s
    }
  end
  
  def success?
    status == 'SUCCESS'
  end
  
  def failure?
    status == 'FAILURE'
  end
  
  def warning?
    status == 'WARNING'
  end
  
  def complete?
    status == 'COMPLETE'
  end

  def note?
    status == 'NOTE'
  end

  def exception?
    failure? and attached['exception']
  end
  
  def mark_read!
    update_attributes read: true
  end

  def to_s
    "[#{status}] #{source}#{to_minutes(attached['elapsed'].to_i) if attached['elapsed']}\n\t#{message}"
  end

  def exception_message
    msg = "#{attached['exception']['type']}: #{attached['exception']['message']}\n\n" 
    
    if attached['exception']['backtrace'].respond_to?(:each)
      attached['exception']['backtrace'].each {|line| msg += "#{line}\n"}
    end
    
    msg
  end
  
  def to_minutes(seconds)
    min = seconds / 60
    sec = seconds % 60
    " #{min > 0 ? "#{min}m," : ""}#{sec}s"
  end
end