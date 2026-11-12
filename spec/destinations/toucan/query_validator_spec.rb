# frozen_string_literal: true

RSpec.describe EventManager::Destinations::Toucan::QueryValidator do
  subject(:validator) { described_class.new }

  let(:event_meta) { { index: "account_activity", operation_name: "user.activity" } }
  let(:filter) { {} }
  let(:pagination) { { from: 1, size: 10 } }
  let(:optionals) { {} }
  let(:destination_type) { EventManager::Destination::TOUCAN }

  def validate!
    validator.validate!(
      event_meta: event_meta,
      filter: filter,
      pagination: pagination,
      optionals: optionals,
      destination_type: destination_type
    )
  end

  it "passes with required fields" do
    expect { validate! }.not_to raise_error
  end

  it "raises ValidationError with destination_type" do
    event_meta[:index] = nil

    expect { validate! }.to raise_error(EventManager::ValidationError) do |error|
      expect(error.message).to match(/index/)
      expect(error.destination_type).to eq(EventManager::Destination::TOUCAN)
    end
  end

  it "requires operation_name" do
    event_meta[:operation_name] = ""
    expect { validate! }.to raise_error(EventManager::ValidationError, /operation_name/)
  end

  it "rejects partial date_range" do
    filter[:date_range] = { start_date: "01/01/2025" }
    expect { validate! }.to raise_error(EventManager::ValidationError, /start_date and end_date/)
  end
end
