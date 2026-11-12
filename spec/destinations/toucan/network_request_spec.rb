# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe EventManager::Destinations::Toucan::Network::Request do
  let(:base_url) { "https://toucan.example.com" }
  let(:client) { described_class.new(base_url: base_url) }

  describe "#query_events" do
    it "posts JSON to the query endpoint" do
      stub_request(:post, "https://toucan.example.com/toucan/index/account_activity/events")
        .with(body: hash_including(operationName: "user.activity"))
        .to_return(status: 200, body: { count: 0, eventHistory: [] }.to_json)

      body = client.query_events(
        index: "account_activity",
        destination_type: EventManager::Destination::TOUCAN,
        input_passed: { event_meta: { index: "account_activity" } },
        operationName: "user.activity",
        from: 1,
        size: 10
      )

      expect(body).to eq("count" => 0, "eventHistory" => [])
    end

    it "raises NetworkError with http_code on HTTP failure" do
      stub_request(:post, "https://toucan.example.com/toucan/index/x/events")
        .to_return(status: 500, body: "error")

      input_passed = { event_meta: { index: "x" } }

      expect do
        client.query_events(
          index: "x",
          destination_type: EventManager::Destination::TOUCAN,
          input_passed: input_passed,
          operationName: "op"
        )
      end.to raise_error(EventManager::NetworkError) { |error|
        expect(error.http_code).to eq(500)
        expect(error.destination_type).to eq(EventManager::Destination::TOUCAN)
        expect(error.input_passed).to eq(input_passed)
      }
    end
  end
end
