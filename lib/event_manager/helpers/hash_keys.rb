# frozen_string_literal: true

module EventManager
  module Helpers
    module HashKeys
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

      def symbolize_top_level(obj)
        return {} unless obj.is_a?(Hash)

        obj.each_with_object({}) do |(key, val), out|
          sym = key.is_a?(Symbol) ? key : key.to_sym
          out[sym] = val
        end
      end

      def symbolize_shallow_keys(hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
