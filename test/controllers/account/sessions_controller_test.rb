require "test_helper"

class Account::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:client)
    sign_in_as @user
    @current = Current.session
  end

  test "index lists only my devices" do
    other_device = @user.sessions.create!(user_agent: "Mozilla/5.0 (iPhone) Safari/604.1")
    someone_else = users(:admin).sessions.create!

    get account_sessions_path
    assert_response :success
    assert_select "#devices tr#session_#{other_device.id}"
    assert_select "#devices tr#session_#{someone_else.id}", count: 0
    assert_select "#session_#{@current.id} .badge", "This device"
  end

  test "destroy signs out another of my devices" do
    other_device = @user.sessions.create!

    delete account_session_path(other_device)
    assert_redirected_to account_sessions_path
    assert_not Session.exists?(other_device.id)
  end

  test "destroy cannot touch another user's device" do
    someone_else = users(:admin).sessions.create!

    delete account_session_path(someone_else)
    assert_response :not_found
    assert Session.exists?(someone_else.id)
  end

  test "destroy refuses to sign out the current device" do
    delete account_session_path(@current)
    assert Session.exists?(@current.id)
  end

  test "others signs out every device except this one" do
    2.times { @user.sessions.create! }

    delete others_account_sessions_path
    assert_redirected_to account_sessions_path
    assert_equal [ @current.id ], @user.sessions.reload.ids
  end
end
