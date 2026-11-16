# frozen_string_literal: true

module EventManager
  module Destinations
    # Query destination contract: validate, adapt out, dispatch, adapt response in.
    module Base
      def validate!(**)
        raise NotImplementedError, "#{self.class} must implement #validate!"
      end

      def adapt(**)
        raise NotImplementedError, "#{self.class} must implement #adapt"
      end

      def dispatch(_built, destination_type:)
        raise NotImplementedError, "#{self.class} must implement #dispatch"
      end

      def adapt_response_to_unified(_raw)
        raise NotImplementedError, "#{self.class} must implement #adapt_response_to_unified"
      end
    end
  end
end
