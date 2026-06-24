class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :access_token
      t.datetime :token_expires_at

      t.timestamps
    end
  end
end
