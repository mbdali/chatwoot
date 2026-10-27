# frozen_string_literal: true

# Raqmi Connect fork, prepended to Whatsapp::IncomingMessageBaseService
# (config/initializers/raqmi_connect.rb).
#
# Intercepts incoming WhatsApp reactions (both customer reactions and coexistence SMB echo reactions).
# Upstream explicitly skips reactions via unprocessable_message_type?; we process and persist them
# into message.content_attributes without any schema changes.
module RaqmiConnect::WhatsappIncomingReaction
  def perform
    processed_params
    return process_reaction_event if reaction_event?

    super
  end

  private

  def reaction_event?
    messages_data.present? && message_type == 'reaction'
  end

  def process_reaction_event
    message_data = messages_data.first
    reaction_data = message_data[:reaction]
    return if reaction_data.blank?

    target_source_id = reaction_data[:message_id]
    return if target_source_id.blank?

    return unless lock_message_source_id!

    set_contact
    return unless @contact
    return if @contact.blocked? && !outgoing_echo

    RaqmiConnect::WhatsappReactionHandler.new(
      inbox: inbox,
      target_source_id: target_source_id,
      emoji: reaction_data[:emoji],
      actor: outgoing_echo ? nil : @contact,
      actor_type: outgoing_echo ? 'User' : 'Contact',
      source_id: message_data[:id],
      timestamp: message_data[:timestamp]
    ).perform
  end
end
