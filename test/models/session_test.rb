require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "records last activity on create" do
    assert users(:client).sessions.create!.last_active_at.present?
  end

  test "expires after the idle timeout" do
    session = users(:client).sessions.create!
    travel Session::IDLE_TIMEOUT + 1.minute do
      assert session.expired?
    end
  end
end
