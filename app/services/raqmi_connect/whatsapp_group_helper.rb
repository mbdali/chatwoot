# frozen_string_literal: true

# Raqmi Connect fork: helper methods for WhatsApp group identification and metadata parsing.
# Zero schema changes: utilizes existing source_id and jsonb attributes.
module RaqmiConnect
  module WhatsappGroupHelper
    module_function

    def group_identifier?(identifier)
      return false if identifier.blank?

      str = identifier.to_s
      str.ends_with?('@g.us') || str.start_with?('group_') || str.match?(/\A\d{10,30}_\d+\z/)
    end

    def extract_group_id(payload_or_message)
      return if payload_or_message.blank?

      if payload_or_message.is_a?(Hash)
        val = payload_or_message.with_indifferent_access
        msg = val[:messages]&.first || val[:message_echoes]&.first || val

        group_id = msg[:group_id].presence ||
                   msg.dig(:context, :group_id).presence ||
                   msg.dig(:context, :group).presence ||
                   val.dig(:group, :id).presence ||
                   val.dig(:groups, 0, :group_id).presence

        return group_id.to_s if group_id.present?

        to_val = msg[:to].to_s
        return to_val if to_val.ends_with?('@g.us')

        from_val = msg[:from].to_s
        return from_val if from_val.ends_with?('@g.us')
      end

      nil
    end

    def extract_group_subject(payload_or_message)
      return if payload_or_message.blank?

      val = payload_or_message.is_a?(Hash) ? payload_or_message.with_indifferent_access : {}
      msg = val[:messages]&.first || val[:message_echoes]&.first || val

      val.dig(:groups, 0, :subject).presence ||
        val.dig(:group, :subject).presence ||
        val.dig(:group, :name).presence ||
        msg[:group_name].presence ||
        msg[:chat_name].presence
    end
  end
end
