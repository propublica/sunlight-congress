# stored internally in MongoDB, not exposed
class BillVersion
  include Mongoid::Document
  include Mongoid::Timestamps

  index "bill.bill_id" => 1
  index bill_version_id: 1
  index issued_on: 1
  index version_code: 1
end