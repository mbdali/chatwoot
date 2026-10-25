# Raqmi Connect fork, prepended to Channel::Whatsapp (config/initializers/raqmi_connect.rb).
#
# Every outbound call to Meta goes through one of these three channel methods, after everything that can
# fail without contacting Meta (template lookup, eligibility, translation). So this is where the marker
# is committed: under the message's row lock, which is released before the HTTP call is made.
module RaqmiConnect::WhatsappDispatchMarker
  def send_message(phone_number, message)
    guard_dispatch(message) { super }
  end

  def send_template(phone_number, template_info, message)
    guard_dispatch(message) { super }
  end

  def send_contact_info_request(identifier, message)
    # Unsupported providers raise before contacting Meta; let them, without a marker.
    return super unless provider == 'whatsapp_cloud'

    guard_dispatch(message) { super }
  end

  private

  def guard_dispatch(message)
    return yield unless message.is_a?(Message) && message.persisted?

    proceed = message.with_lock do
      next false if message.source_id.present?

      if RaqmiConnect::WhatsappDispatch.started?(message)
        RaqmiConnect::WhatsappDispatch.mark_interrupted!(message)
        next false
      end

      mark_dispatch_started(message)
      true
    end

    yield if proceed
  end

  def mark_dispatch_started(message)
    attrs = (message.content_attributes || {}).deep_dup
    attrs[RaqmiConnect::WhatsappDispatch::MARKER] = Time.current.utc.iso8601
    # No callbacks: no extra broadcast or webhook for a bookkeeping write.
    message.update_columns(content_attributes: attrs) # rubocop:disable Rails/SkipsModelValidations
  end
end
