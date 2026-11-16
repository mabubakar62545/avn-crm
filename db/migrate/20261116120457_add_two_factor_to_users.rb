class AddTwoFactorToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_secret, :string
    add_column :users, :otp_enabled_at, :datetime
    add_column :users, :otp_last_used_at, :integer

    create_table :recovery_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :recovery_codes, [ :user_id, :code_digest ], unique: true
  end
end
