# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module EventManager
  module Destinations
    module Toucan
      module Network
        class Request
          DEFAULT_OPEN_TIMEOUT = 5

          def initialize(base_url:, open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: nil)
            @base_url = parse_base_url!(base_url)
            @open_timeout = open_timeout
            @read_timeout = read_timeout
          end

          def query_events(index:, destination_type:, **payload)
            path = "/toucan/index/#{index}/events"
            post_json(path, payload, destination_type: destination_type)
          end

          private

          def post_json(path, data, destination_type:)
            uri = full_url(path)
            http = build_http_client(uri)
            request = Net::HTTP::Post.new(uri)
            request["Content-Type"] = "application/json"
            request.body = data.to_json

            response = http.request(request)
            handle_response(response, destination_type: destination_type)
          rescue Net::OpenTimeout, Net::ReadTimeout => e
            raise network_error(
              "request timeout: #{e.message}",
              destination_type: destination_type,
              http_code: :request_timeout,
              cause: e
            )
          rescue SocketError => e
            raise network_error(
              "service unavailable: #{e.message}",
              destination_type: destination_type,
              http_code: :service_unavailable,
              cause: e
            )
          end

          def handle_response(response, destination_type:)
            code = response.code.to_i
            return parse_body(response.body, destination_type: destination_type) if code == 200

            raise network_error(
              "query failed with HTTP #{code}: #{response.body}",
              destination_type: destination_type,
              http_code: code
            )
          end

          def parse_body(body, destination_type:)
            return {} if body.nil? || body.empty?

            JSON.parse(body)
          rescue JSON::ParserError => e
            raise ResponseError.new(
              "invalid JSON response: #{e.message}",
              destination_type: destination_type,
              cause: e
            )
          end

          def network_error(message, destination_type:, http_code: nil, cause: nil)
            NetworkError.new(
              message,
              destination_type: destination_type,
              http_code: http_code,
              cause: cause
            )
          end

          def build_http_client(uri)
            http = Net::HTTP.new(uri.hostname, uri.port)
            http.use_ssl = uri.scheme == "https"
            http.open_timeout = @open_timeout
            http.read_timeout = @read_timeout if @read_timeout
            http
          end

          def full_url(path)
            relative = path.start_with?("/") ? path.delete_prefix("/") : path
            URI.join("#{@base_url}/", relative)
          end

          def parse_base_url!(raw)
            uri = URI.parse(raw.to_s.strip)
            raise ConfigurationError, "Invalid destination url: #{raw}" unless uri.is_a?(URI::HTTP)

            uri
          end
        end
      end
    end
  end
end
