require 'csv'

class BillsNicknames

  # options:
  #   cache: only download if missing
  #   remote: override link to CSV

  def self.run(options = {})

    FileUtils.mkdir_p "data/unitedstates"

    remote = options[:remote] || "https://raw.github.com/unitedstates/bill-nicknames/master/bill-nicknames.csv"
    destination = "data/unitedstates/bill-nicknames.csv"

    unless options[:cache] and File.exists?(destination)
      puts "Downloading bill-nicknames.csv..."
      unless results = Utils.curl(remote, destination)
        Report.failure self, "Couldn't download bill nicknames, bailing out."
        return
      end
    end

    # load the contents of the CSV into 
    nicknames = {}

    CSV.foreach(destination) do |row|
      next unless row[0] and ["hr", "hres", "hjres", "hcronres", "s" ,"sres", "sjres", "sconres"].include?(row[0])
      
      bill_type = row[0].strip
      number = row[1].strip
      congress = row[2].strip
      term = row[3].strip

      bill_id = "#{bill_type}#{number}-#{congress}"
      
      if term.present?
        nicknames[bill_id] ||= []
        nicknames[bill_id] << term
        puts "[#{bill_id}] #{term}" if options[:debug]
      else
        puts "Bad or blank term for #{bill_id}."
      end
    end

    count = 0
    nicknames.each do |bill_id, names|
      unless bill = Bill.where(bill_id: bill_id).first
        puts "Couldn't find bill by #{bill_id}, skipping."
        next
      end

      bill['nicknames'] = names
      bill.save!
      count += 1
    end

    Report.success self, "Updated #{count} bills with their popular nicknames."
  end

end