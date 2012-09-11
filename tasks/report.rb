class Report
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :status
  field :source
  field :message
  field :elapsed_time, type: Float
  field :attached, type: Hash
  
  field :read, type: Boolean, default: false
  
  index status: 1
  index source: 1
  index read: 1
  index created_at: 1
  
  scope :unread , where(read: false)
  
  def self.file(status, source, message, rest = {})
    Report.create!({source: source.to_s, status: status, message: message}.merge(rest))
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
  
  def mark_read!
    update_attributes read: true
  end

  def to_s
    msg = "[#{status}] #{source}#{elapsed_time ? " [#{to_minutes elapsed_time.to_i}]" : ""}\n\t#{message}"
    if self[:exception]
      msg += "\n\t#{self[:exception]['type']}: #{self[:exception]['message']}"
      if self[:exception]['backtrace'] and self[:exception]['backtrace'].respond_to?(:each)
        self[:exception]['backtrace'].each {|line| msg += "\n\t\t#{line}"}
      end
    end
    msg
  end
  
  def to_minutes(seconds)
    min = seconds / 60
    sec = seconds % 60
    "#{min > 0 ? "#{min}m," : ""}#{sec}s"
  end

  def self.exception_to_hash(exception)
    {
        'backtrace' => exception.backtrace, 
        'message' => exception.message, 
        'type' => exception.class.to_s
    }
  end
end