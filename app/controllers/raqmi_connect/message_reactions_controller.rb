# frozen_string_literal: true

# Raqmi Connect fork: controller for adding/removing emoji reactions to messages.
# Dispatches to WhatsApp Cloud API for WhatsApp conversations and updates content_attributes.
class RaqmiConnect::MessageReactionsController < Api::V1::Accounts::Conversations::BaseController
  before_action :set_message

  rescue_from CustomExceptions::WhatsappReactionError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    emoji = params[:emoji].to_s.strip
    if emoji.blank?
      return render json: { error: I18n.t('conversations.messages.whatsapp.reaction_blank_error', default: 'Emoji cannot be blank.') },
                    status: :unprocessable_entity
    end

    dispatch_source_id = nil
    channel = @conversation.inbox.channel

    if channel.is_a?(Channel::Whatsapp)
      validate_whatsapp_reaction_eligibility!
      dispatch_source_id = channel.send_reaction(@conversation.contact_inbox.source_id, @message.source_id, emoji)
    end

    RaqmiConnect::WhatsappReactionHandler.new(
      inbox: @conversation.inbox,
      target_message: @message,
      emoji: emoji,
      actor: current_user,
      actor_type: 'User',
      source_id: dispatch_source_id
    ).perform

    render json: {
      message_id: @message.id,
      reactions: @message.reload.content_attributes['reactions'] || []
    }
  end

  def destroy
    channel = @conversation.inbox.channel

    if channel.is_a?(Channel::Whatsapp) && @message.source_id.present? && @conversation.can_reply?
      channel.send_reaction(@conversation.contact_inbox.source_id, @message.source_id, '')
    end

    RaqmiConnect::WhatsappReactionHandler.new(
      inbox: @conversation.inbox,
      target_message: @message,
      emoji: '',
      actor: current_user,
      actor_type: 'User'
    ).perform

    render json: {
      message_id: @message.id,
      reactions: @message.reload.content_attributes['reactions'] || []
    }
  end

  private

  def set_message
    @message = @conversation.messages.find(params[:message_id] || params[:id])
  end

  def validate_whatsapp_reaction_eligibility!
    if @message.source_id.blank?
      raise CustomExceptions::WhatsappReactionError,
            I18n.t('conversations.messages.whatsapp.reaction_missing_source_id',
                   default: 'Cannot react to a message without a WhatsApp message ID.')
    end

    return if @conversation.can_reply?

    raise CustomExceptions::WhatsappReactionError,
          I18n.t('errors.whatsapp.message_outside_messaging_window',
                 default: 'Cannot react outside the 24-hour messaging window.')
  end
end
