# cache class - stores zips to districts
class Zip
  include Mongoid::Document

  field :zip
  field :districts, type: Hash

  index zip: 1
end