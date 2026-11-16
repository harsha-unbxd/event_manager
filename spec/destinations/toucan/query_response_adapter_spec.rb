# frozen_string_literal: true

RSpec.describe EventManager::Destinations::Toucan::Adapters::QueryResponseAdapter do
  subject(:adapter) { described_class.new }

  it "maps Toucan body to unified rows" do
    toucan_body = {
      "count" => 1,
      "eventHistory" => [
        {
          "startTimeMillis" => 1_700_000_000_000,
          "message" => "logged in",
          "operationName" => "user.activity",
          "tags" => { "event_name" => "user.login", "ip_tag" => "1.2.3.4" },
          "eventContext" => { "eventId" => "abc", "user" => "a@example.com" }
        }
      ]
    }

    result = adapter.adapt(toucan_body)

    expect(result[:total]).to eq(1)
    expect(result[:data].length).to eq(1)
    expect(result[:data].first).to include(
      event_name: "user_activity",
      message: "logged in",
      id: "abc",
      user: { email: "a@example.com" }
    )
    expect(result[:data].first[:metadata]).to eq(
      "event_name" => "user.login",
      "ip" => "1.2.3.4"
    )
  end

  it "decodes operation from operation_name_tag when operationName is absent" do
    toucan_body = {
      count: 1,
      eventHistory: [
        {
          startTimeMillis: 1_700_000_000_000,
          message: "x",
          tags: { "operation_name_tag" => "user.send_invite" },
          eventContext: { eventId: "1", user: "u@example.com" }
        }
      ]
    }

    row = adapter.adapt(toucan_body)[:data].first

    expect(row[:event_name]).to eq("user_send_invite")
    expect(row[:metadata]).to eq("operation_name" => "user.send_invite")
  end
end
