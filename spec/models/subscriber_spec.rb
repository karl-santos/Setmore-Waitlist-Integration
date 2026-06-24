require 'rails_helper'

RSpec.describe Subscriber, type: :model do
  # Test that a valid subscriber can be created
  it "is valid with a phone number and expires_at" do
    subscriber = build(:subscriber)
    expect(subscriber).to be_valid
  end

  # Test that phone number is required
  it "is invalid without a phone number" do
    subscriber = build(:subscriber, phone_number: nil)
    expect(subscriber).to_not be_valid
  end

  # Test that duplicate active subscriptions are blocked
  it "does not allow duplicate active phone numbers" do
    create(:subscriber)
    duplicate = build(:subscriber)
    expect(duplicate).to_not be_valid
  end

  # Test that an expired subscriber can resubscribe
  it "allows resubscription after expiry" do
    create(:subscriber, expires_at: Time.now - 1.day)
    resubscriber = build(:subscriber)
    expect(resubscriber).to be_valid
  end

  # Test the active scope
  it "returns only active subscribers" do
    active = create(:subscriber)
    create(:subscriber, phone_number: "+14169999999", opted_out: true)
    expect(Subscriber.active).to eq([ active ])
  end
end
