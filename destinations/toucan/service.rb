# frozen_string_literal: true

require_relative "../../lib/event_manager/helpers/blank"
require_relative "../../lib/event_manager/helpers/hash_keys"
require_relative "../../lib/event_manager/helpers/tag_metadata"
require_relative "validators/query_validator"
require_relative "adapters/query_request_adapter"
require_relative "adapters/query_response_adapter"
require_relative "network/request"

module EventManager
  module Destinations
    module Toucan
      class Service
        def initialize(
          validator: nil,
          request_adapter: nil,
          response_adapter: nil,
          request: nil,
          base_url: nil
        )
          @validator = validator || QueryValidator.new
          @request_adapter = request_adapter || Adapters::QueryRequestAdapter.new
          @response_adapter = response_adapter || Adapters::QueryResponseAdapter.new
          url = base_url || Configuration.destination_url
          @request = request || Network::Request.new(base_url: url)
        end

        def query_events(event_meta:, filter:, pagination:, destination_type:)
          @validator.validate!(
            event_meta: event_meta,
            filter: filter,
            pagination: pagination,
            destination_type: destination_type
          )

          built = @request_adapter.adapt(
            event_meta: event_meta,
            filter: filter,
            pagination: pagination
          )

          raw = @request.query_events(
            index: built[:index],
            destination_type: destination_type,
            **built[:body]
          )
          @response_adapter.adapt(raw)
        end
      end
    end
  end
end
