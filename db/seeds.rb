# Idempotent: safe to run any number of times (`bin/rails db:seed`).
#
# In development and test this creates one verified account per role so every
# screen can be exercised without going through email confirmation:
#
#   admin@avn-crm.test    / TestPassword123!   (admin: users, roles, audit log)
#   manager@avn-crm.test  / TestPassword123!   (manager: read-only user list)
#   client@avn-crm.test   / TestPassword123!   (client: own account only)
#   locked@avn-crm.test   / TestPassword123!   (locked out, to test "Unlock")
#   pending@avn-crm.test  / TestPassword123!   (email not confirmed yet)

if Rails.env.local?
  password = "TestPassword123!"

  demo_users = [
    { email_address: "admin@avn-crm.test",   role: "admin" },
    { email_address: "mmabubakar850@gmail.com",   role: "admin" },
    { email_address: "manager@avn-crm.test", role: "manager" },
    { email_address: "client@avn-crm.test",  role: "client" },
    { email_address: "locked@avn-crm.test",  role: "client", locked_until: 1.day.from_now, failed_login_attempts: 0 },
    { email_address: "pending@avn-crm.test", role: "client", verified_at: nil }
   ]

  demo_users.each do |attrs|
    User.find_or_create_by!(email_address: attrs[:email_address]) do |user|
      user.password = password
      user.role = attrs[:role]
      user.verified_at = attrs.fetch(:verified_at, Time.current)
    end.tap do |user|
      # update_columns: lock state is cleared by a before_save on password change
      user.update_columns(locked_until: attrs[:locked_until]) if attrs.key?(:locked_until)
    end
  end

  puts "Seeded #{demo_users.size} demo users (password: #{password})" unless Rails.env.test?
end
