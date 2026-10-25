# Raqmi Connect fork, prepended to SendReplyJob (config/initializers/raqmi_connect.rb).
#
# A WhatsApp send is never retried by Sidekiq: whatever escapes the service is recorded as a failure.
# Other channels re-raise, so their upstream retries still apply.
module RaqmiConnect::SendReplyJobDispatchFailure
  def self.prepended(base)
    # ActiveJob checks the last-declared handler first: StandardError first, the specific classes after.
    base.discard_on(StandardError) { |job, error| job.send(:record_whatsapp_dispatch_failure, error) }
    base.discard_on(*RaqmiConnect::WhatsappDispatch::CONNECTION_ERRORS) do |job, error|
      job.send(:record_whatsapp_dispatch_failure, error)
    end
  end

  private

  def record_whatsapp_dispatch_failure(error)
    arg = arguments.first
    message = arg.is_a?(Message) ? arg : Message.find_by(id: arg)
    return unless message
    raise error unless RaqmiConnect::WhatsappDispatch.whatsapp?(message)

    RaqmiConnect::WhatsappDispatch.record_failure!(message, error)
  end
end
