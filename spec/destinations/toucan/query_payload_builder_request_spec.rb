# frozen_string_literal: true

RSpec.describe EventManager::Destinations::Toucan::QueryPayloadBuilder, ".build_request" do
  let(:event_meta) { { index: "account_activity", operation_name: "user.activity" } }
  let(:pagination) { { from: 2, size: 5 } }

  def build_request(filter:, optionals: {})
    described_class.build_request(
      event_meta: event_meta,
      filter: filter,
      pagination: pagination,
      optionals: optionals
    )
  end

  it "maps unified input to Toucan request (auth-master fluent payload)" do
    filter = {
      site_keys: ["123"],
      users: ["a@example.com"],
      event_types: ["user_login"],
      date_range: { start_date: "01/11/2025", end_date: "10/11/2025" }
    }

    result = build_request(filter: filter, optionals: { status: "ok" })

    expect(result[:index]).to eq("account_activity")
    expect(result[:body]).to include(
      siteKeys: ["123"],
      operationName: "user.activity",
      from: 2,
      size: 5,
      users: ["a@example.com"]
    )
    expect(result[:body][:tags]).to include(
      "event_name" => ["user.login"],
      "status" => "ok"
    )
    expect(result[:body]).to have_key(:startTimeMillis)
    expect(result[:body]).to have_key(:endTimeMillis)
  end

  it "omits tags when event_types and optionals are empty (auth-master with_tags skip)" do
    result = build_request(filter: { site_keys: ["1"] })

    expect(result[:body][:tags]).to be_nil
  end

  it "encodes multiple site_keys" do
    result = build_request(filter: { site_keys: %w[a b] })

    expect(result[:body][:siteKeys]).to eq(%w[a b])
  end
end
