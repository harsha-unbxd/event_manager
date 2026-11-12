# frozen_string_literal: true

module EventManager
  module Helpers
    module Blank
      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def present?(value)
        !blank?(value)
      end
    end
  end
end
