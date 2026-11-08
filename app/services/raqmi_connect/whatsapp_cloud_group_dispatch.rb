# frozen_string_literal: true

# Raqmi Connect fork, prepended to Whatsapp::Providers::WhatsappCloudService (config/initializers/raqmi_connect.rb).
#
# Adds support for sending messages to WhatsApp groups via Meta WhatsApp Cloud API.
# When the destination is a group (or the message belongs to a group conversation), overrides the
# default individual recipient payload with `recipient_type: 'group'` and `to: <group_id>`.
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

    private

    def group_dispatch?(phone_number, message)
      return true if RaqmiConnect::WhatsappGroupHelper.group_identifier?(phone_number)
      return true if message&.conversation&.additional_attributes&.dig('is_group')
      return true if message&.conversation&.contact&.additional_attributes&.dig('is_group')

      false
    end
  end
end
