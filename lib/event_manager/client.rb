# frozen_string_literal: true

module EventManager
  class Client
    def query_events(event_meta:, filter: {}, pagination: {}, optionals: {})
      event_meta = deep_symbolize_keys(event_meta)
      filter = deep_symbolize_keys(filter || {})
      pagination = deep_symbolize_keys(pagination || {})
      optionals = deep_symbolize_keys(optionals || {})

      destination_type = Configuration.destination_type
      raise ConfigurationError, "destination is not configured" if blank?(destination_type)

      destination_service.query_events(
        event_meta: event_meta,
        filter: filter,
        pagination: pagination,
        optionals: optionals,
        destination_type: destination_type
      )
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

    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(key, val), out|
          out[key.to_sym] = deep_symbolize_keys(val)
        end
      when Array
        obj.map { |item| deep_symbolize_keys(item) }
      else
        obj
      end
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end
  end
end
