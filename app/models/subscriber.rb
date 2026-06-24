class Subscriber < ApplicationRecord
  validates :phone_number, presence: true, uniqueness: true

  # this lets you do Subscriber.active to get all active subscribers
  # active means they have not opted out and their subscription has not expired
  scope :active, -> { where(opted_out: false).where("expires_at > ?", Time.now) }
end
