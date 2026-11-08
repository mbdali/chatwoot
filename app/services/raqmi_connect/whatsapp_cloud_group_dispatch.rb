# frozen_string_literal: true

# Raqmi Connect fork, prepended to Whatsapp::Providers::WhatsappCloudService (config/initializers/raqmi_connect.rb).
#
# Adds support for sending messages to WhatsApp groups via Meta WhatsApp Cloud API:
# 1. When destination is a group, overrides recipient payload with `recipient_type: 'group'` and `to: <group_id>`.
# 2. Handles text, attachments/media, and templates.
# 3. Gracefully converts interactive messages (buttons/lists) to formatted plain text, since Meta Cloud API
#    does not support interactive payload types in group chats.
module RaqmiConnect
  module WhatsappCloudGroupDispatch
    def send_text_message(phone_number, message)
      return super unless group_dispatch?(phone_number, message)

      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'group',
        to: phone_number,
        text: { body: message.outgoing_content },
        type: 'text'
      }
      reply_context = whatsapp_reply_context(message)
      payload[:context] = reply_context if reply_context.present?

      response = HTTParty.post(
        "#{phone_id_path}/messages",
        headers: api_headers,
        body: payload.to_json
      )

      process_response(response, message)
    end

    def send_attachment_message(phone_number, message)
      return super unless group_dispatch?(phone_number, message)

      attachment = message.attachments.first
      normalize_opus_content_type(attachment)
      type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
      type_content = build_attachment_content(type, attachment, message)

      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'group',
        to: phone_number,
        type: type,
        type.to_s => type_content
      }
      reply_context = whatsapp_reply_context(message)
      payload[:context] = reply_context if reply_context.present?

      response = HTTParty.post(
        "#{phone_id_path('v24.0')}/messages",
        headers: api_headers,
        body: payload.to_json
      )

      process_response(response, message)
    end

    def send_template(phone_number, template_info, message)
      return super unless group_dispatch?(phone_number, message)

      template_body = template_body_parameters(template_info)
      request_body = {
        messaging_product: 'whatsapp',
        recipient_type: 'group',
        to: phone_number,
        type: 'template',
        template: template_body
      }

      response = HTTParty.post(
        "#{phone_id_path}/messages",
        headers: api_headers,
        body: request_body.to_json
      )

      process_response(response, message)
    end

    def send_interactive_text_message(phone_number, message)
      return super unless group_dispatch?(phone_number, message)

      # Meta Cloud API does not support interactive button/list messages in groups.
      # Fall back to formatted plain text so group members can still read and respond to options.
      text_body = format_interactive_content(message)
      text_message = message.dup
      text_message.define_singleton_method(:outgoing_content) { text_body }

      send_text_message(phone_number, text_message)
    end

    private

    def group_dispatch?(phone_number, message)
      return true if RaqmiConnect::WhatsappGroupHelper.group_identifier?(phone_number)
      return true if message&.conversation&.additional_attributes&.dig('is_group')
      return true if message&.conversation&.contact&.additional_attributes&.dig('is_group')

      false
    end

    def format_interactive_content(message)
      base_text = message.outgoing_content.to_s
      items = message.content_attributes&.dig('items')
      return base_text if items.blank?

      options_text = items.each_with_index.map do |item, idx|
        title = item['title'] || item[:title]
        description = item['description'] || item[:description]
        description.present? ? "#{idx + 1}. #{title} - #{description}" : "#{idx + 1}. #{title}"
      end.join("\n")

      base_text.present? ? "#{base_text}\n\n#{options_text}" : options_text
    end
  end
end
