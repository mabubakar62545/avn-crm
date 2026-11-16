class CreateAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_events do |t|
      t.bigint   :actor_id                       # who did it (nil = anonymous/system)
      t.bigint   :user_id                        # who it happened to
      t.string   :user_email                     # snapshot, survives user deletion/email change
      t.string   :action, null: false
      t.string   :ip_address
      t.string   :user_agent
      t.string   :request_id
      t.json     :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :audit_events, [ :user_id, :created_at ]
    add_index :audit_events, [ :actor_id, :created_at ]
    add_index :audit_events, [ :action, :created_at ]
  end
end