# frozen_string_literal: true

module EventManager
  module EventNameCodec
    module_function

    def encode_slug(slug)
      slug.to_s.tr("_", ".")
    end

    def decode_slug(toucan_event_name)
      toucan_event_name.to_s.tr(".", "_")
    end
  end
end
