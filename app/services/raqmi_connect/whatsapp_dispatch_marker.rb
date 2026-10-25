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

  # Locks a fresh copy of the row, never the caller's object: upstream mutates the message in memory before
  # it gets here (TemplateParameterConverterService rewrites additional_attributes for legacy params), and
  # Rails refuses to lock a record with unsaved changes.
  def guard_dispatch(message)
    return yield unless message.is_a?(Message) && message.persisted?

    stamp = Message.transaction do
      row = Message.lock.find(message.id)
      next if row.source_id.present?

      if RaqmiConnect::WhatsappDispatch.started?(row)
        RaqmiConnect::WhatsappDispatch.mark_interrupted!(row)
        next
      end

      mark_dispatch_started(row)
    end
    return if stamp.nil?

    # The caller classifies a failure by the marker, so its copy must carry it too.
    message.content_attributes[RaqmiConnect::WhatsappDispatch::MARKER] = stamp
    yield
  end

  def mark_dispatch_started(row)
    stamp = Time.current.utc.iso8601
    attrs = (row.content_attributes || {}).deep_dup
    attrs[RaqmiConnect::WhatsappDispatch::MARKER] = stamp
    # No callbacks: no extra broadcast or webhook for a bookkeeping write.
    row.update_columns(content_attributes: attrs) # rubocop:disable Rails/SkipsModelValidations
    stamp
  end
end
