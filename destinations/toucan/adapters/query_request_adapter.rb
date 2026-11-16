# frozen_string_literal: true

module EventManager
  module Destinations
    module Toucan
      module Adapters
        class QueryRequestAdapter
          include EventManager::Helpers::Blank

          def adapt(event_meta:, filter:, pagination:)
            site_keys = Array(filter[:site_keys]).compact
            site_key = site_keys.length == 1 ? site_keys.first : site_keys
            operation_names = normalize_event_names(filter[:event_names])
            date_filter = filter[:date_range]

            body = NativePayload
                   .new(
                     site_key,
                     operation_names,
                     filter[:users],
                     pagination.fetch(:from, 1),
                     pagination.fetch(:size, 20),
                     date_filter,
                     self
                   )
                   .with_site_keys
                   .with_operation_names
                   .with_users
                   .with_limits
                   .with_date_filter
                   .with_tags(filter)
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

          def normalize_event_names(raw)
            Array(raw).flatten.compact.reject { |name| blank?(name) }
          end

          # Mirrors auth-master ToucanQueryBuilder::Payload
          class NativePayload
            include EventManager::Helpers::Blank
            include EventManager::Helpers::HashKeys

            def initialize(site_key, operation_names, users, from, size, date_filter, adapter)
              @site_key = site_key
              @operation_names = operation_names
              @users = users
              @from = from
              @size = size
              @date_filter = date_filter
              @adapter = adapter
              @payload = {}
            end

            def with_site_keys
              @payload[:siteKeys] = Array(@site_key).flatten.compact
              self
            end

            def with_operation_names
              names = Array(@operation_names).reject { |name| blank?(name) }
              return self if blank?(names)

              @payload[:operationNames] = names.map { |name| EventNameCodec.encode_slug(name) }
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

            def with_tags(filter)
              extra = tag_entries_from_filter(filter)

              return self if extra.empty?

              @payload[:tags] = (@payload[:tags] || {}).merge(extra)
              self
            end

            def build
              @payload
            end

            private

            def tag_entries_from_filter(filter)
              extra = {}
              account_id = filter[:account_id]
              extra["account_id"] = account_id if present?(account_id)

              merge_tag_hash!(extra, filter[:optionals])
              extra
            end

            def merge_tag_hash!(extra, tag_hash)
              return extra unless tag_hash.is_a?(Hash)

              tag_hash.each do |key, value|
                next if blank?(value)

                extra[key.to_s] = value
              end
              extra
            end

            def parse_date(value)
              QueryValidator::DATE_FORMATS.each do |fmt|
                return Date.strptime(value.to_s, fmt)
              rescue ArgumentError
                next
              end

              @adapter.validation_fail!("Invalid date format, expected DD/MM/YYYY or YYYY-MM-DD: #{value}")
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
end
