class RenameMemberRoleToClientAndAddInvitations < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :users, name: "users_role_check"
    execute "UPDATE users SET role = 'client' WHERE role = 'member'"
    change_column_default :users, :role, from: "member", to: "client"
    add_check_constraint :users, "role IN ('client', 'manager', 'admin')", name: "users_role_check"

    add_column :users, :invited_at, :datetime
    add_reference :users, :invited_by, foreign_key: { to_table: :users, on_delete: :nullify }
  end

  def down
    remove_reference :users, :invited_by, foreign_key: { to_table: :users }
    remove_column :users, :invited_at

    remove_check_constraint :users, name: "users_role_check"
    execute "UPDATE users SET role = 'member' WHERE role = 'client'"
    change_column_default :users, :role, from: "client", to: "member"
    add_check_constraint :users, "role IN ('member', 'manager', 'admin')", name: "users_role_check"
  end
end
