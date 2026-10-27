# frozen_string_literal: true

# Raqmi Connect fork, prepended to Whatsapp::Providers::WhatsappCloudService
# (config/initializers/raqmi_connect.rb).
#
# Adds dispatch of emoji reactions to Meta WhatsApp Cloud API.
module RaqmiConnect::WhatsappCloudReactions
  def send_reaction(phone_number, target_source_id, emoji)
    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        **recipient_params(phone_number),
        type: 'reaction',
        reaction: {
          message_id: target_source_id,
          emoji: emoji.to_s
        }
      }.to_json
    )

    if response.success? && response.parsed_response.is_a?(Hash) && response.parsed_response['error'].blank?
      response.parsed_response.dig('messages', 0, 'id')
    else
      err_msg = error_message(response) || "Meta WhatsApp Cloud API reaction failed (HTTP #{response.code})"
      Rails.logger.error("[WHATSAPP REACTION DISPATCH ERROR] #{err_msg}")
      raise CustomExceptions::WhatsappReactionError, err_msg
    end
  end
end
