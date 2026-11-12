# frozen_string_literal: true

module EventManager
  module Destinations
    module Toucan
      class QueryPayloadBuilder
        DATE_FILTER_FORMAT = "%d/%m/%Y"

        class << self
          def build_request(event_meta:, filter:, pagination:, optionals:)
            new.build_request(
              event_meta: event_meta,
              filter: filter,
              pagination: pagination,
              optionals: optionals
            )
          end

          def build_response(toucan_body)
            new.build_response(toucan_body: toucan_body)
          end
        end

        def build_request(event_meta:, filter:, pagination:, optionals:)
          @event_meta = event_meta
          @filter = filter
          @pagination = pagination
          @optionals = optionals

          site_keys = Array(filter[:site_keys]).compact
          site_key = site_keys.length == 1 ? site_keys.first : site_keys
          event_filters = { events: filter[:event_types] }
          date_filter = filter[:date_range]

          body = RequestPayload
                 .new(
                   site_key,
                   event_filters,
                   event_meta[:operation_name],
                   filter[:users],
                   pagination.fetch(:from, 1),
                   pagination.fetch(:size, 20),
                   date_filter,
                   self
                 )
                 .with_site_keys
                 .with_operation_name
                 .with_tags
                 .with_users
                 .with_limits
                 .with_date_filter
                 .with_unified_tag_filters(filter: filter, optionals: optionals)
                 .build

          {
            index: event_meta[:index].to_s,
            body: body
          }
        end

        def build_response(toucan_body:)
          ResponsePayload
            .new(toucan_body)
            .with_total
            .with_data
            .build
        end

        def validation_fail!(message)
          ctx = error_context
          raise ValidationError.new(
            message,
            destination_type: ctx[:destination_type],
            input_passed: ctx[:input_passed]
          )
        end

        private

        def error_context
          {
            destination_type: Configuration.destination_type,
            input_passed: {
              event_meta: @event_meta,
              filter: @filter,
              pagination: @pagination,
              optionals: @optionals
            }
          }
        end

        # Mirrors auth-master ToucanQueryBuilder::Payload
        class RequestPayload
          EVENT_NAME_TAG = "event_name"

          def initialize(site_key, event_filters, operation_name, users, from, size, date_filter, builder)
            @site_key = site_key
            @event_filters = event_filters
            @operation_name = operation_name
            @users = users
            @from = from
            @size = size
            @date_filter = date_filter
            @builder = builder
            @payload = {}
          end

          def with_site_keys
            @payload[:siteKeys] = Array(@site_key).flatten.compact
            self
          end

          def with_operation_name
            @payload[:operationName] = @operation_name
            self
          end

          def with_tags
            encoded = encode_event_names
            return self if blank?(encoded)

            @payload[:tags] = { EVENT_NAME_TAG => encoded }
            self
          end

          def with_users
            return self if blank?(@users)

            @payload[:users] = Array(@users).compact
            self
          end

          def with_limits
            @payload[:from] = @from
            @payload[:size] = @size
            self
          end

          def with_date_filter
            return self if blank?(@date_filter)

            filter = symbolize_keys(@date_filter)
            start_date = parse_date(filter[:start_date])
            end_date = parse_date(filter[:end_date])

            @payload[:startTimeMillis] = start_of_day_ms(start_date)
            @payload[:endTimeMillis] = end_of_day_ms(end_date)
            self
          end

          def with_unified_tag_filters(filter:, optionals:)
            extra = {}
            account_id = filter[:account_id]
            extra["account_id"] = account_id if present?(account_id)

            optionals.each do |key, value|
              next if blank?(value)

              extra[key.to_s] = value
            end

            return self if extra.empty?

            @payload[:tags] = (@payload[:tags] || {}).merge(extra)
            self
          end

          def build
            @payload
          end

          private

          def encode_event_names
            events = @event_filters[:events]
            return if blank?(events)

            Array(events).compact.map { |item| EventNameCodec.encode_slug(item) }
          end

          def parse_date(value)
            QueryValidator::DATE_FORMATS.each do |fmt|
              return Date.strptime(value.to_s, fmt)
            rescue ArgumentError
              next
            end

            @builder.validation_fail!("Invalid date format, expected DD/MM/YYYY or YYYY-MM-DD: #{value}")
          end

          def start_of_day_ms(date)
            (Time.utc(date.year, date.month, date.day).to_f * 1000).to_i
          end

          def end_of_day_ms(date)
            time = Time.utc(date.year, date.month, date.day) + (24 * 60 * 60) - 1
            (time.to_f * 1000).to_i
          end

          def symbolize_keys(hash)
            hash.transform_keys(&:to_sym)
          end

          def present?(value)
            !blank?(value)
          end

          def blank?(value)
            value.nil? || (value.respond_to?(:empty?) && value.empty?)
          end
        end

        # Mirrors auth-master ToucanQueryResponseBuilder
        class ResponsePayload
          EVENT_NAME_TAG = "event_name_tag"

          METADATA_LABELS = {
            "ip_tag" => "IP",
            "user-agent_tag" => "User Agent",
            "country_tag" => "Country"
          }.freeze

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

          private

          def symbolize_top_level(obj)
            return {} unless obj.is_a?(Hash)

            obj.each_with_object({}) do |(key, val), out|
              sym = key.is_a?(Symbol) ? key : key.to_sym
              out[sym] = val
            end
          end

          class EventEntry
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
              @entry[:metadata] = build_metadata(@tags)
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

            def build_metadata(tags)
              normalized = tags.is_a?(Hash) ? tags : {}
              normalized.each_with_object({}) do |(tag_key, value), metadata|
                next if tag_key.to_s == ResponsePayload::EVENT_NAME_TAG
                next if tag_key.to_s == "event_name"
                next if blank?(value)

                metadata[metadata_label(tag_key)] = value
              end
            end

            def metadata_label(tag_key)
              key = tag_key.to_s
              labels = ResponsePayload::METADATA_LABELS
              labels[key] || key.sub(/_tag\z/, "").tr("_-", " ").split.map(&:capitalize).join(" ")
            end

            def symbolize_entry(entry)
              return entry.with_indifferent_access if entry.respond_to?(:with_indifferent_access)

              symbolize_top_level(entry)
            end

            def symbolize_top_level(obj)
              return {} unless obj.is_a?(Hash)

              obj.each_with_object({}) do |(key, val), out|
                sym = key.is_a?(Symbol) ? key : key.to_sym
                out[sym] = val
              end
            end

            def blank?(value)
              value.nil? || (value.respond_to?(:empty?) && value.empty?)
            end
          end
        end
      end
    end
  end
end
