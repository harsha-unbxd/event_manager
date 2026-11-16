# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe EventManager do
  before do
    EventManager::Configuration.reset!
    described_class.configure do |c|
      c.destination = {
        type: EventManager::Destination::TOUCAN,
        url: "https://toucan.example.com"
      }
    end
  end

  after { EventManager::Configuration.reset! }

  it "queries through the configured Toucan destination" do
    stub_request(:post, "https://toucan.example.com/toucan/index/account_activity/events")
      .to_return(
        status: 200,
        body: {
          count: 1,
          eventHistory: [
            {
              startTimeMillis: 1_700_000_000_000,
              message: "ok",
              operationName: "user.activity",
              tags: { event_name: "user.login" },
              eventContext: { eventId: "1", user: "u@example.com" }
            }
          ]
        }.to_json
      )

    result = described_class.query_events(
      event_meta: { index: "account_activity" },
      filter: {
        site_keys: ["9"],
        event_names: ["user_activity"],
        optionals: { status: "active" }
      },
      pagination: { from: 1, size: 10 }
    )

    expect(result[:total]).to eq(1)
    expect(result[:data].first[:event_name]).to eq("user_activity")
  end
end
