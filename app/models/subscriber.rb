class Subscriber < ApplicationRecord
  validates :phone_number, presence: true, uniqueness: {
    conditions: -> { active }
  }

  # this lets you do Subscriber.active to get all active subscribers
  # active means they have not opted out and their subscription has not expired
  scope :active, -> { where(opted_out: false).where("expires_at > ?", Time.now) }
end
