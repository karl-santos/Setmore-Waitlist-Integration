class AvailableSlot < ApplicationRecord
  # every slot must have a datetime and be unique
  validates :slot_datetime, presence: true, uniqueness: true
end
