# frozen_string_literal: true

RSpec.describe EventManager::Destinations::Toucan::QueryPayloadBuilder, ".build_response" do
  it "maps Toucan body to unified rows" do
    toucan_body = {
      "count" => 1,
      "eventHistory" => [
        {
          "startTimeMillis" => 1_700_000_000_000,
          "message" => "logged in",
          "tags" => { "event_name" => "user.login", "ip_tag" => "1.2.3.4" },
          "eventContext" => { "eventId" => "abc", "user" => "a@example.com" }
        }
      ]
    }

    result = described_class.build_response(toucan_body)

    expect(result[:total]).to eq(1)
    expect(result[:data].length).to eq(1)
    expect(result[:data].first).to include(
      event: "user_login",
      message: "logged in",
      id: "abc",
      user: { email: "a@example.com" }
    )
    expect(result[:data].first[:metadata]).to include("IP" => "1.2.3.4")
  end

  it "decodes event from event_name_tag like auth-master response builder" do
    toucan_body = {
      count: 1,
      eventHistory: [
        {
          startTimeMillis: 1_700_000_000_000,
          message: "x",
          tags: { "event_name_tag" => "user.send_invite" },
          eventContext: { eventId: "1", user: "u@example.com" }
        }
      ]
    }

    row = described_class.build_response(toucan_body)[:data].first

    expect(row[:event]).to eq("user_send_invite")
    expect(row[:metadata]).not_to have_key("Event Name Tag")
  end
end
