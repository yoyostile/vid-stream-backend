class User < ActiveRecord::Base
  has_many :streams
  validates_uniqueness_of :device_uuid
end
