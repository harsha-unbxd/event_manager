# frozen_string_literal: true

module EventManager
  class Configuration
    class << self
      attr_reader :destination

      def configure
        yield(self)
      end

      def destination=(value)
        @destination = normalize_destination(value)
      end

      def destination_type
        destination&.fetch(:type)
      end

      def destination_url
        url = destination&.fetch(:url)
        raise ConfigurationError, "destination url is required" if blank?(url)

        url.to_s.strip
      end

      def reset!
        @destination = nil
      end

      private

      def normalize_destination(value)
        raise ConfigurationError, "destination must be a Hash" unless value.is_a?(Hash)

        config = deep_symbolize_keys(value)
        type = config[:type]
        raise ConfigurationError, "destination type is required" if blank?(type)

        config
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
end
