# frozen_string_literal: true

module EventManager
  module Destinations
    module Toucan
      class QueryValidator
        MAX_DATE_RANGE_DAYS = 90
        MAX_PAGE_SIZE = 100
        DATE_FORMATS = ["%d/%m/%Y", "%Y-%m-%d"].freeze

        def validate!(event_meta:, filter:, pagination:, optionals:, destination_type:) # rubocop:disable Lint/UnusedMethodArgument
          validate_event_meta!(event_meta, destination_type: destination_type)
          validate_pagination!(pagination, destination_type: destination_type)
          return if blank?(filter[:date_range])

          validate_date_range!(filter[:date_range], destination_type: destination_type)
        end

        private

        def validate_event_meta!(event_meta, destination_type:)
          if blank?(event_meta[:index])
            validation_fail!("event_meta.index is required", destination_type: destination_type)
          end
          return unless blank?(event_meta[:operation_name])

          validation_fail!(
            "event_meta.operation_name is required",
            destination_type: destination_type
          )
        end

        def validate_pagination!(pagination, destination_type:)
          from = pagination.fetch(:from, 1)
          size = pagination.fetch(:size, 20)

          if from.to_i < 1
            validation_fail!("pagination.from must be at least 1", destination_type: destination_type)
          end
          if size.to_i < 1
            validation_fail!("pagination.size must be at least 1", destination_type: destination_type)
          end
          return unless size.to_i > MAX_PAGE_SIZE

          validation_fail!(
            "pagination.size cannot exceed #{MAX_PAGE_SIZE}",
            destination_type: destination_type
          )
        end

        def validate_date_range!(date_range, destination_type:)
          range = date_range.transform_keys(&:to_sym)
          start_raw = range[:start_date]
          end_raw = range[:end_date]

          if blank?(start_raw) || blank?(end_raw)
            validation_fail!(
              "filter.date_range requires start_date and end_date",
              destination_type: destination_type
            )
          end

          start_date = parse_date!(start_raw, destination_type: destination_type)
          end_date = parse_date!(end_raw, destination_type: destination_type)
          today = Date.today
          earliest = today - MAX_DATE_RANGE_DAYS

          if start_date < earliest
            validation_fail!(
              "start_date cannot be older than #{MAX_DATE_RANGE_DAYS} days",
              destination_type: destination_type
            )
          end
          if end_date > today
            validation_fail!("end_date cannot be after today", destination_type: destination_type)
          end
          if end_date < earliest
            validation_fail!(
              "end_date cannot be older than #{MAX_DATE_RANGE_DAYS} days",
              destination_type: destination_type
            )
          end
          return unless end_date < start_date

          validation_fail!(
            "end_date cannot be before start_date",
            destination_type: destination_type
          )
        end

        def parse_date!(value, destination_type:)
          DATE_FORMATS.each do |fmt|
            return Date.strptime(value.to_s, fmt)
          rescue ArgumentError
            next
          end

          validation_fail!(
            "Invalid date format, expected DD/MM/YYYY or YYYY-MM-DD: #{value}",
            destination_type: destination_type
          )
        end

        def validation_fail!(message, destination_type:)
          raise ValidationError.new(
            message,
            destination_type: destination_type
          )
        end

        def blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end
