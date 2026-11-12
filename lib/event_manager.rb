# frozen_string_literal: true

require_relative "event_manager/version"
require_relative "event_manager/helpers/blank"
require_relative "event_manager/helpers/hash_keys"
require_relative "event_manager/helpers/tag_metadata"
require_relative "event_manager/destination"
require_relative "event_manager/errors"
require_relative "event_manager/event_name_codec"
require_relative "event_manager/configuration"
require_relative "event_manager/client"
require_relative "../destinations/toucan/service"

module EventManager
  class << self
    def configure(&block)
      Configuration.configure(&block)
    end

    def query_events(**kwargs)
      Client.new.query_events(**kwargs)
    end
  end
end
