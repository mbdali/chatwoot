# frozen_string_literal: true

# Raqmi Connect fork, prepended to Channel::Whatsapp
# (config/initializers/raqmi_connect.rb).
#
# Adds send_reaction delegation to Channel::Whatsapp.
module RaqmiConnect::WhatsappChannelReactions
  def send_reaction(phone_number, target_source_id, emoji)
    unless provider_service.respond_to?(:send_reaction)
      raise CustomExceptions::WhatsappReactionError, "Provider #{provider} does not support emoji reactions"
    end

    provider_service.send_reaction(phone_number, target_source_id, emoji)
  end
end
