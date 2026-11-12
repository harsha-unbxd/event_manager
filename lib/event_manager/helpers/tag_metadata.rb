# frozen_string_literal: true

module EventManager
  module Helpers
    module TagMetadata
      def normalize_tag_key(tag_key)
        tag_key.to_s.sub(/_tag\z/, "")
      end

      def normalize_tags_to_metadata(tags)
        return {} unless tags.is_a?(Hash)

        tags.each_with_object({}) do |(tag_key, value), metadata|
          metadata[normalize_tag_key(tag_key)] = value
        end
      end
    end
  end
end
