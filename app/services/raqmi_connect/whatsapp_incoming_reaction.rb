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

    actor_details = reaction_actor_details(message_data)

    RaqmiConnect::WhatsappReactionHandler.new(
      inbox: inbox,
      target_source_id: target_source_id,
      emoji: reaction_data[:emoji],
      actor: outgoing_echo ? nil : @contact,
      actor_type: outgoing_echo ? 'User' : 'Contact',
      source_id: message_data[:id],
      timestamp: message_data[:timestamp],
      **actor_details
    ).perform
  end

  def reaction_actor_details(message_data)
    return {} if outgoing_echo
    return {} unless RaqmiConnect::WhatsappGroupHelper.extract_group_id(message_data || processed_params).present?

    sender_phone = message_data[:from].to_s.presence
    sender_user_id = message_data[:from_user_id].to_s.presence
    contacts = Array(processed_params[:contacts])
    entry = contacts.find do |c|
      (sender_phone.present? && c[:wa_id].to_s == sender_phone) ||
        (sender_user_id.present? && c[:user_id].to_s == sender_user_id)
    end
    name = entry&.dig(:profile, :name).presence || sender_phone || sender_user_id

    {
      actor_id: sender_phone || sender_user_id,
      actor_name: name
    }.compact
  end
end
