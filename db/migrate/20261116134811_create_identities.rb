class CreateIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string   :provider, null: false
      t.string   :uid, null: false            # the IdP's immutable "sub" claim
      t.string   :email                       # informational only, never used for lookup
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :identities, [ :provider, :uid ], unique: true
    add_index :identities, [ :user_id, :provider ], unique: true
  end
end
