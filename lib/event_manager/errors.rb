# frozen_string_literal: true

module EventManager
  class Error < StandardError
    attr_reader :destination_type, :input_passed, :cause

    def initialize(message = nil, destination_type: nil, input_passed: nil, cause: nil)
      super(message)
      @destination_type = destination_type
      @input_passed = input_passed.freeze if input_passed.is_a?(Hash)
      @input_passed ||= {}
      @cause = cause
    end
  end

  class ValidationError < Error; end

  class NetworkError < Error
    attr_reader :http_code

    def initialize(message = nil, destination_type: nil, input_passed: nil, http_code: nil, cause: nil)
      super(message, destination_type: destination_type, input_passed: input_passed, cause: cause)
      @http_code = http_code
    end
  end

  class ResponseError < Error; end

  # Boot / configure only — does not inherit EventManager::Error and carries no input_passed.
  class ConfigurationError < StandardError; end
end
