# db/migrate/20261116111609_add_last_active_at_to_sessions.rb
class AddLastActiveAtToSessions < ActiveRecord::Migration[8.0]
  def up
    add_column :sessions, :last_active_at, :datetime
    execute "UPDATE sessions SET last_active_at = updated_at"
    change_column_null :sessions, :last_active_at, false
    add_index :sessions, :last_active_at
  end

  def down
    remove_index  :sessions, :last_active_at
    remove_column :sessions, :last_active_at
  end
end