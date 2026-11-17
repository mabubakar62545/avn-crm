require "rails_helper"

# Guards that every action either authorizes a record or uses policy_scope,
# so a new action that forgets Pundit fails loudly instead of leaking data.
RSpec.describe ApplicationController do
  controller do
    def index = head(:ok)
    def show  = head(:ok)
  end

  before do
    user = create(:user)
    Current.session = user.sessions.create!
    cookies.signed[:session_id] = Current.session.id
  end

  it "raises when an index action skips policy_scope" do
    expect { get :index }.to raise_error(Pundit::PolicyScopingNotPerformedError)
  end

  it "raises when any other action skips authorize" do
    expect { get :show, params: { id: 1 } }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end

  it "still requires authentication first" do
    cookies.delete(:session_id)
    Current.reset
    get :show, params: { id: 1 }
    expect(response).to redirect_to(new_session_path)
  end
end
