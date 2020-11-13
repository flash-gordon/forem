require 'dry/effects'

current_time = Object.new.tap {
  _1.extend(Dry::Effects.CurrentTime)
}.method(:current_time)

FactoryBot.define do
  factory :ahoy_message, class: "Ahoy::Message" do
    user
  end

  factory :ahoy_visit, class: "Ahoy::Visit" do
    user
    started_at { current_time.() }
  end

  factory :ahoy_event, class: "Ahoy::Event" do
    user
    visit { create(:ahoy_visit, user: user) } # Ahoy::Events require an Ahoy::Visit
    time { current_time.() }
    name { "Clicked Welcome Notification" }
    properties { { title: "welcome_notification_welcome_thread" } }
  end
end
