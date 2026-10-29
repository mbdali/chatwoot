# frozen_string_literal: true

module RaqmiConnect
  module ChatwootHubSilence
    def sync_with_hub
      nil
    end

    def register_instance(*)
      nil
    end

    def emit_event(*)
      nil
    end

    def send_push(*)
      nil
    end

    def send_push_with_response(*)
      nil
    end

    def support_config
      {
        support_website_token: nil,
        support_script_url: nil,
        support_identifier_hash: nil
      }
    end
  end
end
