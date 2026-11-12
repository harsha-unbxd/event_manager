# frozen_string_literal: true

module EventManager
  class Configuration
    class << self
      include Helpers::Blank
      include Helpers::HashKeys

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
    end
  end
end
