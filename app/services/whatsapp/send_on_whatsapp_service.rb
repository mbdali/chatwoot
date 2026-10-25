class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  CONNECTION_ERRORS = [Net::OpenTimeout, Errno::ECONNREFUSED, SocketError].freeze

  def perform
    return if message.source_id.present?
    return handle_interrupted_dispatch if interrupted_dispatch?

    super
  rescue *CONNECTION_ERRORS => e
    handle_connection_error(e)
  rescue StandardError, Timeout::Error => e
    handle_dispatch_error(e)
  end

  private

  def handle_connection_error(error)
    return if message.source_id.present?

    attrs = (message.content_attributes || {}).except('dispatch_started_at', :dispatch_started_at)
    message.update!(status: :failed, external_error: "DISPATCH_NOT_SENT: #{error.class}", content_attributes: attrs)
  end

  def handle_dispatch_error(error)
    return if message.source_id.present?
    return handle_connection_error(error) if connection_error?(error)

    error_message = if dispatch_started?
                      "DISPATCH_UNKNOWN: #{error.class}: #{error.message}"
                    else
                      "DISPATCH_NOT_SENT: #{error.class}: #{error.message}"
                    end

    message.update!(status: :failed, external_error: error_message)
  end

  def connection_error?(error)
    CONNECTION_ERRORS.any? { |klass| error.is_a?(klass) }
  end

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    return if message.source_id.present?
    return handle_interrupted_dispatch if interrupted_dispatch?

    if template_params.present?
      tag_contact_info_template_request
      return send_template_message
    end
    return send_contact_info_request if contact_info_request?

    return send_session_message if message.conversation.can_reply?

    message.update!(status: :failed, external_error: I18n.t('errors.whatsapp.message_outside_messaging_window'))
  rescue CustomExceptions::WhatsappContactInfoRequestError => e
    message.update!(status: :failed, external_error: e.message)
  end

  def send_contact_info_request
    Whatsapp::ContactInfoRequestEligibilityService.new(
      conversation: message.conversation, message: message, delivery_mode: :interactive
    ).ensure_available!

    dispatch_to_meta do
      message_id = channel.send_contact_info_request(message.conversation.contact_inbox.source_id, message)
      message.update!(source_id: message_id) if message_id.present?
    end
  end

  def send_template_message
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    dispatch_to_meta do
      message_id = channel.send_template(message.conversation.contact_inbox.source_id, {
                                           name: name,
                                           namespace: namespace,
                                           lang_code: lang_code,
                                           parameters: processed_parameters
                                         }, message)
      message.update!(source_id: message_id) if message_id.present?
    end
  end

  def send_session_message
    dispatch_to_meta do
      message_id = channel.send_message(message.conversation.contact_inbox.source_id, message)
      message.update!(source_id: message_id) if message_id.present?
    end
  end

  def dispatch_to_meta
    return if message.source_id.present?

    if interrupted_dispatch?
      handle_interrupted_dispatch
      return
    end

    mark_dispatch_started!
    yield
  end

  def interrupted_dispatch?
    dispatch_started? && message.source_id.blank?
  end

  def dispatch_started?
    (message.content_attributes&.[]('dispatch_started_at') || message.content_attributes&.[](:dispatch_started_at)).present?
  end

  def handle_interrupted_dispatch
    message.update!(status: :failed, external_error: 'DISPATCH_UNKNOWN: interrupted dispatch')
  end

  def mark_dispatch_started!
    attrs = (message.content_attributes&.deep_dup || {}).merge('dispatch_started_at' => Time.now.utc.iso8601)
    # rubocop:disable Rails/SkipsModelValidations
    message.update_columns(content_attributes: attrs)
    # rubocop:enable Rails/SkipsModelValidations
    message.content_attributes = attrs
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end

  def contact_info_request?
    message.content_attributes&.dig('whatsapp_contact_info', 'type') == 'request'
  end

  def tag_contact_info_template_request
    eligibility = Whatsapp::ContactInfoRequestEligibilityService.new(
      conversation: message.conversation, message: message, delivery_mode: :template, template_params: template_params
    )
    return unless eligibility.request_contact_info_template?(template_params)

    message.conversation.contact_inbox.with_lock do
      eligibility.ensure_available!
      content_attributes = message.content_attributes.deep_dup
      content_attributes['whatsapp_contact_info'] = { 'type' => 'request', 'state' => 'pending', 'delivery_mode' => 'template' }
      message.update!(content_attributes: content_attributes)
    end
  end
end
