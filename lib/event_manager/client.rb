# frozen_string_literal: true

module EventManager
  class Client
    include Helpers::Blank
    include Helpers::HashKeys

    def query_events(event_meta:, filter: {}, pagination: {})
      event_meta = deep_symbolize_keys(event_meta)
      filter = deep_symbolize_keys(filter || {})
      pagination = deep_symbolize_keys(pagination || {})

      destination_type = Configuration.destination_type
      raise ConfigurationError, "destination is not configured" if blank?(destination_type)

      dest = destination_service

      dest.validate!(event_meta: event_meta, filter: filter, pagination: pagination, destination_type: destination_type)
      built = dest.adapt(event_meta: event_meta, filter: filter, pagination: pagination)
      raw = dest.dispatch(built, destination_type: destination_type)
      dest.adapt_response_to_unified(raw)
    end

    private

    def destination_service
      case Configuration.destination_type
      when Destination::TOUCAN
        Destinations::Toucan::Service.new
      else
        raise ConfigurationError, "unsupported destination type: #{Configuration.destination_type.inspect}"
      end
    end
  end
end
