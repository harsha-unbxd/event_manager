# frozen_string_literal: true

module EventManager
  module Destinations
    module Toucan
      class QueryResponseBuilder
        def build_response(toucan_body)
          ResponsePayload
            .new(toucan_body)
            .with_total
            .with_data
            .build
        end

        class ResponsePayload
          include EventManager::Helpers::HashKeys

          EVENT_NAME_TAG = "event_name_tag"

          def initialize(toucan_body)
            @body = symbolize_top_level(toucan_body)
            @response = {}
          end

          def with_total
            @response[:total] = @body[:count].to_i
            self
          end

          def with_data
            @response[:data] = Array(@body[:eventHistory]).map do |entry|
              EventEntry
                .new(entry)
                .with_event
                .with_timestamp
                .with_message
                .with_id
                .with_user
                .with_metadata
                .build
            end
            self
          end

          def build
            @response
          end

          class EventEntry
            include EventManager::Helpers::Blank
            include EventManager::Helpers::HashKeys
            include EventManager::Helpers::TagMetadata
            def initialize(entry)
              @record = symbolize_entry(entry)
              @tags = @record[:tags] || @record["tags"] || {}
              @event_context = @record[:eventContext] || @record["eventContext"] || {}
              @entry = {}
            end

            def with_event
              raw_name = tag_value(EVENT_NAME_TAG) || tag_value("event_name")
              @entry[:event] = EventNameCodec.decode_slug(raw_name)
              self
            end

            def with_timestamp
              @entry[:timestamp] = timestamp_from_millis(@record[:startTimeMillis] || @record["startTimeMillis"])
              self
            end

            def with_message
              @entry[:message] = @record[:message] || @record["message"]
              self
            end

            def with_id
              ctx = symbolize_top_level(@event_context)
              @entry[:id] = ctx[:eventId]
              self
            end

            def with_user
              ctx = symbolize_top_level(@event_context)
              @entry[:user] = { email: ctx[:user] }
              self
            end

            def with_metadata
              @entry[:metadata] = normalize_tags_to_metadata(@tags)
              self
            end

            def build
              @entry
            end

            private

            def tag_value(key)
              @tags[key] || @tags[key.to_sym]
            end

            def timestamp_from_millis(millis)
              return nil if blank?(millis)

              Time.at(millis.to_f / 1000).utc.iso8601
            end

            def symbolize_entry(entry)
              return entry.with_indifferent_access if entry.respond_to?(:with_indifferent_access)

              symbolize_top_level(entry)
            end
          end
        end
      end
    end
  end
end
