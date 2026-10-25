# Raqmi Connect fork: the rules behind the WhatsApp dispatch marker (docs/api-integration-guide.md §5).
#
# Every outbound WhatsApp message is billed by Meta, so a message must reach Meta at most once.
# `content_attributes['dispatch_started_at']` is committed immediately before the HTTP call; a message
# that carries it but has no `source_id` (the wamid) may already have been sent, and is never sent again.
module RaqmiConnect::WhatsappDispatch
  MARKER = 'dispatch_started_at'.freeze
  NOT_SENT = 'DISPATCH_NOT_SENT:'.freeze
  UNKNOWN = 'DISPATCH_UNKNOWN:'.freeze

  # The connection never opened, so nothing reached Meta even after the marker.
  CONNECTION_ERRORS = [Net::OpenTimeout, Errno::ECONNREFUSED, SocketError].freeze

  module_function

  def whatsapp?(message)
    message&.conversation&.inbox&.channel_type == 'Channel::Whatsapp'
  end

  def started?(message)
    attrs = message.content_attributes || {}
    (attrs[MARKER] || attrs[MARKER.to_sym]).present?
  end

  def connection_error?(error)
    CONNECTION_ERRORS.any? { |klass| error.is_a?(klass) }
  end

  def attributes_without_marker(message)
    (message.content_attributes || {}).except(MARKER, MARKER.to_sym)
  end

  def mark_interrupted!(message)
    message.update!(status: :failed, external_error: "#{UNKNOWN} interrupted dispatch")
  end

  # A dispatch that raised: connection errors are NOT_SENT (and lose the marker, so a retry may send);
  # anything else is NOT_SENT before the marker and UNKNOWN after it.
  def record_failure!(message, error)
    return if message.source_id.present?

    if connection_error?(error)
      message.update!(status: :failed, external_error: "#{NOT_SENT} #{error.class}",
                      content_attributes: attributes_without_marker(message))
    elsif started?(message)
      message.update!(status: :failed, external_error: "#{UNKNOWN} #{error.class}: #{error.message}")
    else
      message.update!(status: :failed, external_error: "#{NOT_SENT} #{error.class}: #{error.message}")
    end
  end
end
