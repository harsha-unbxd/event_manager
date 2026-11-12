# frozen_string_literal: true

RSpec.describe EventManager::ValidationError do
  it "exposes destination_type and message" do
    error = described_class.new(
      "event_meta.index is required",
      destination_type: EventManager::Destination::TOUCAN
    )

    expect(error.message).to eq("event_meta.index is required")
    expect(error.destination_type).to eq(EventManager::Destination::TOUCAN)
    expect(error).not_to respond_to(:http_code)
  end
end

RSpec.describe EventManager::NetworkError do
  it "exposes http_code" do
    error = described_class.new(
      "failed",
      destination_type: EventManager::Destination::TOUCAN,
      http_code: 503
    )

    expect(error.http_code).to eq(503)
  end
end

RSpec.describe EventManager::ConfigurationError do
  it "is not a subclass of EventManager::Error" do
    expect(described_class).not_to be < EventManager::Error
  end
end
