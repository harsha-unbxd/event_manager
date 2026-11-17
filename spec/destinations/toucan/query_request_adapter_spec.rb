# frozen_string_literal: true

RSpec.describe EventManager::Destinations::Toucan::Adapters::QueryRequestAdapter do
  subject(:adapter) { described_class.new }

  let(:event_meta) { { topic: "account_activity" } }
  let(:pagination) { { from: 2, size: 5 } }

  def adapt(filter:)
    adapter.adapt(
      event_meta: event_meta,
      filter: filter,
      pagination: pagination
    )
  end

  it "maps unified input to Toucan request (auth-master fluent payload)" do
    filter = {
      site_keys: ["123"],
      users: ["a@example.com"],
      event_names: ["user_activity"],
      date_range: { start_date: "01/11/2025", end_date: "10/11/2025" }
    }

    result = adapt(filter: filter.merge(optionals: { status: "ok" }))

    expect(result[:index]).to eq("account_activity")
    expect(result[:body]).to include(
      siteKeys: ["123"],
      operationNames: ["user.activity"],
      from: 2,
      size: 5,
      users: ["a@example.com"]
    )
    expect(result[:body][:tags]).to include("status" => "ok")
    expect(result[:body]).to have_key(:startTimeMillis)
    expect(result[:body]).to have_key(:endTimeMillis)
  end

  it "omits operationNames when event_names is blank" do
    result = adapt(filter: { site_keys: ["123"] })

    expect(result[:body]).not_to have_key(:operationNames)
  end

  it "omits operationNames when event_names is an empty list" do
    result = adapt(filter: { site_keys: ["123"], event_names: [] })

    expect(result[:body]).not_to have_key(:operationNames)
  end

  it "omits operationNames when event_names contains only blank values" do
    result = adapt(filter: { site_keys: ["123"], event_names: ["", nil] })

    expect(result[:body]).not_to have_key(:operationNames)
  end

  it "maps filter.optionals to Toucan tags" do
    result = adapt(
      filter: {
        site_keys: ["1"],
        optionals: { "region" => "us", status: "ok" }
      }
    )

    expect(result[:body][:tags]).to eq("region" => "us", "status" => "ok")
  end

  it "omits tags when optionals and account_id are empty" do
    result = adapt(filter: { site_keys: ["1"] })

    expect(result[:body][:tags]).to be_nil
  end

  it "encodes multiple site_keys" do
    result = adapt(filter: { site_keys: %w[a b] })

    expect(result[:body][:siteKeys]).to eq(%w[a b])
  end

  it "sends multiple event_names as Toucan operationNames" do
    result = adapt(
      filter: { site_keys: ["1"], event_names: %w[user_activity account_updated] }
    )

    expect(result[:body][:operationNames]).to eq(%w[user.activity account.updated])
  end

  it "sends operationNames and tags on the same payload" do
    result = adapt(
      filter: {
        site_keys: ["abdbdbdbd="],
        event_names: ["user_activity"],
        optionals: { "event_name" => ["user.login"] }
      }
    )

    expect(result[:body][:siteKeys]).to eq(["abdbdbdbd="])
    expect(result[:body][:operationNames]).to eq(["user.activity"])
    expect(result[:body][:tags]).to eq("event_name" => ["user.login"])
  end
end
