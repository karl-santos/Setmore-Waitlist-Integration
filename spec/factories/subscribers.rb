FactoryBot.define do
  factory :subscriber do
    phone_number { "+14161234567" }
    expires_at { Time.now + 7.days }
    opted_out { false }
  end
end
