# Raqmi Connect fork, prepended to Api::V1::Accounts::Conversations::MessagesController
# (config/initializers/raqmi_connect.rb).
#
# The dashboard's Retry clears source_id and sends again. For WhatsApp that is a second paid message, so:
# - a message the ERP sent (content_attributes.erp_outbox_id) is never retried here — the ERP owns resends
#   (caps, reason, audit), and a retried message would be read back as the original;
# - a DISPATCH_UNKNOWN message is never retried: it may already have been delivered and charged;
# - any other failed WhatsApp message may be retried, and loses its marker so the dispatch guard sends it.
module RaqmiConnect::MessageRetryGuard
  private

  def claim_message_retry
    refuse_unsafe_whatsapp_retry! if message.failed? && RaqmiConnect::WhatsappDispatch.whatsapp?(message)

    super
  end

  def clear_source_id
    super
    return unless RaqmiConnect::WhatsappDispatch.whatsapp?(message) && RaqmiConnect::WhatsappDispatch.started?(message)

    message.update!(content_attributes: RaqmiConnect::WhatsappDispatch.attributes_without_marker(message))
  end

  def refuse_unsafe_whatsapp_retry!
    attrs = message.content_attributes || {}
    if (attrs['erp_outbox_id'] || attrs[:erp_outbox_id]).present?
      raise CustomExceptions::MessageRetryError, I18n.t('conversations.messages.retry.erp_outbox_error')
    end
    return unless message.external_error.to_s.start_with?(RaqmiConnect::WhatsappDispatch::UNKNOWN)

    raise CustomExceptions::MessageRetryError, I18n.t('conversations.messages.retry.dispatch_unknown_error')
  end
end
