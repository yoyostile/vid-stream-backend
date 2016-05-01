class Stream < ActiveRecord::Base
  belongs_to :user
  before_create :set_public_uuid
  validates_uniqueness_of :public_id

  scope :all_active, -> () { where(active: true) }

  def to_param
    self.public_id
  end

  private
  def set_public_uuid
    self.public_id = SecureRandom.uuid
  end
end
