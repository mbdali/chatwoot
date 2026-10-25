# Raqmi Connect fork, prepended to Whatsapp::SendOnWhatsappService (config/initializers/raqmi_connect.rb).
#
# Refuses a message that may already have been sent, and records every exception out of the dispatch as a
# failure instead of letting it reach Sidekiq, whose retry would send the message again.
module RaqmiConnect::WhatsappDispatchFailure
  def perform
    return if message.source_id.present?
    return RaqmiConnect::WhatsappDispatch.mark_interrupted!(message) if RaqmiConnect::WhatsappDispatch.started?(message)

    super
  rescue StandardError => e # Net::ReadTimeout and every Timeout::Error included
    RaqmiConnect::WhatsappDispatch.record_failure!(message, e)
  end
end
