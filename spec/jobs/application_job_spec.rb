require "rails_helper"

RSpec.describe ApplicationJob do
  it "is the base class for the app's jobs" do
    expect(described_class.superclass).to eq(ActiveJob::Base)
  end
end
