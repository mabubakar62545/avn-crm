class AddPasswordSetAtToUsers < ActiveRecord::Migration[8.1]
  # Lightweight models so the backfill doesn't depend on app code.
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationIdentity < ActiveRecord::Base
    self.table_name = "identities"
  end

  def up
    add_column :users, :password_set_at, :datetime

    # Accounts created through Google sign-up got their identity in the same
    # transaction as the user row. Everyone else chose their own password.
    sso_provisioned = MigrationIdentity.joins("INNER JOIN users ON users.id = identities.user_id")
                                       .where("identities.created_at <= datetime(users.created_at, '+1 minute')")
                                       .pluck(:user_id)
    MigrationUser.where.not(id: sso_provisioned).update_all("password_set_at = created_at")
  end

  def down
    remove_column :users, :password_set_at
  end
end
