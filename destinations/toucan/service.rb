# frozen_string_literal: true

require_relative "../../lib/event_manager/helpers/blank"
require_relative "../../lib/event_manager/helpers/hash_keys"
require_relative "../../lib/event_manager/helpers/tag_metadata"
require_relative "validators/query_validator"
require_relative "builders/query_request_builder"
require_relative "builders/query_response_builder"
require_relative "network/request"

module EventManager
  module Destinations
    module Toucan
      class Service
        def initialize(
          validator: nil,
          request_builder: nil,
          response_builder: nil,
          request: nil,
          base_url: nil
        )
          @validator = validator || QueryValidator.new
          @request_builder = request_builder || QueryRequestBuilder.new
          @response_builder = response_builder || QueryResponseBuilder.new
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

          built = @request_builder.build_request(
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
          @response_builder.build_response(raw)
        end
      end
    end
  end
end
