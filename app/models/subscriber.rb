class Subscriber < ApplicationRecord
  validates :phone_number, presence: true, uniqueness: {
    conditions: -> { active }
    }, format: {
      with: /\A\+[1-9]\d{7,14}\z/,
      message: "must be in international format e.g. +14161234567"
    }


  # Subscriber.active to get all active subscribers
  # active means they have not opted out and their subscription has not expired
  scope :active, -> { where(opted_out: false).where("expires_at > ?", Time.now) }
end
