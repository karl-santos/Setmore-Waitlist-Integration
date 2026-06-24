class CreateAvailableSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :available_slots do |t|
      t.datetime :slot_datetime
      t.datetime :last_seen_at

      t.timestamps
    end
  end
end
