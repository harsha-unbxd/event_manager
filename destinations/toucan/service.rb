# frozen_string_literal: true

require_relative "validators/query_validator"
require_relative "builders/query_payload_builder"
require_relative "network/request"

module EventManager
  module Destinations
    module Toucan
      class Service
        def initialize(
          validator: nil,
          builder: nil,
          request: nil,
          base_url: nil
        )
          @validator = validator || QueryValidator.new
          @builder = builder || QueryPayloadBuilder
          url = base_url || Configuration.destination_url
          @request = request || Network::Request.new(base_url: url)
        end

        def query_events(event_meta:, filter:, pagination:, optionals:, destination_type:)
          @validator.validate!(
            event_meta: event_meta,
            filter: filter,
            pagination: pagination,
            optionals: optionals,
            destination_type: destination_type
          )

          built = @builder.build_request(
            event_meta: event_meta,
            filter: filter,
            pagination: pagination,
            optionals: optionals
          )

          raw = @request.query_events(
            index: built[:index],
            destination_type: destination_type,
            **built[:body]
          )
          @builder.build_response(raw)
        end
      end
    end
  end
end
