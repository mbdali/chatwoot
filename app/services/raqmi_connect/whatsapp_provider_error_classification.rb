# Raqmi Connect fork, prepended to Whatsapp::Providers::BaseService (config/initializers/raqmi_connect.rb).
#
# Meta answering 5xx may have processed the message before failing, so the outcome is unknown, never a
# plain failure (which would read as "safe to resend"). 4xx answers keep upstream handling.
module RaqmiConnect::WhatsappProviderErrorClassification
  private

  def handle_error(response, message)
    return super unless message.present? && response.respond_to?(:code) && response.code.to_i >= 500

    Rails.logger.error response.body
    message.external_error = "#{RaqmiConnect::WhatsappDispatch::UNKNOWN} HTTP #{response.code}"
    message.status = :failed
    message.save!
  end
end
