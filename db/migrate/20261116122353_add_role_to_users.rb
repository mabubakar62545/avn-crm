class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, null: false, default: "member"
    add_check_constraint :users, "role IN ('member', 'manager', 'admin')", name: "users_role_check"
  end
end
