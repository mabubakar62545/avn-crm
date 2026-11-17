require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "connects with a valid session cookie and identifies the user" do
    session = create(:session)
    cookies.signed[:session_id] = session.id

    connect "/cable"

    expect(connection.current_user).to eq(session.user)
  end

  it "rejects a connection without a session cookie" do
    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects a connection for a session that no longer exists" do
    session = create(:session)
    cookies.signed[:session_id] = session.id
    session.destroy!

    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects an unsigned (forged) cookie" do
    cookies[:session_id] = create(:session).id.to_s
    expect { connect "/cable" }.to have_rejected_connection
  end
end
