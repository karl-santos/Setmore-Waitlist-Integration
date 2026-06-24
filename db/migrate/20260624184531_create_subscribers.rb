class CreateSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :subscribers do |t|
      t.string :phone_number
      t.datetime :expires_at
      t.boolean :opted_out, default: false

      t.timestamps
    end
  end
end
