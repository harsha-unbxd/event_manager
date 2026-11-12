# frozen_string_literal: true

module EventManager
  module Destinations
    module Toucan
      class QueryRequestBuilder
        def build_request(event_meta:, filter:, pagination:, optionals:)
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

        def validation_fail!(message)
          raise ValidationError.new(
            message,
            destination_type: Configuration.destination_type
          )
        end

        # Mirrors auth-master ToucanQueryBuilder::Payload
        class RequestPayload
          include EventManager::Helpers::Blank
          include EventManager::Helpers::HashKeys

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

            filter = symbolize_shallow_keys(@date_filter)
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
        end
      end
    end
  end
end
