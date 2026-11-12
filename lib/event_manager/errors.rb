# frozen_string_literal: true

module EventManager
  class Error < StandardError
    attr_reader :destination_type, :cause

    def initialize(message = nil, destination_type: nil, cause: nil)
      super(message)
      @destination_type = destination_type
      @cause = cause
    end
  end

  class ValidationError < Error; end

  class NetworkError < Error
    attr_reader :http_code

    def initialize(message = nil, destination_type: nil, http_code: nil, cause: nil)
      super(message, destination_type: destination_type, cause: cause)
      @http_code = http_code
    end
  end

  class ResponseError < Error; end

  class ConfigurationError < StandardError; end
end
