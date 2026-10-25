class SendReplyJob < ApplicationJob
  queue_as :high

  CONNECTION_NOT_SENT_ERRORS = [Net::OpenTimeout, Errno::ECONNREFUSED, SocketError].freeze

  # ActiveJob evaluates rescue/discard handlers in reverse declaration order (last declared runs first).
  # Declare StandardError first, specific classes after.
  discard_on StandardError do |job, error|
    job.send(:handle_whatsapp_failure, error, "DISPATCH_UNKNOWN: #{error.class}: #{error.message}")
  end

  discard_on(*CONNECTION_NOT_SENT_ERRORS) do |job, error|
    job.send(:handle_whatsapp_failure, error, "DISPATCH_NOT_SENT: #{error.class}")
  end

  CHANNEL_SERVICES = {
    'Channel::TwitterProfile' => ::Twitter::SendOnTwitterService,
    'Channel::TwilioSms' => ::Twilio::SendOnTwilioService,
    'Channel::Line' => ::Line::SendOnLineService,
    'Channel::Telegram' => ::Telegram::SendOnTelegramService,
    'Channel::Whatsapp' => ::Whatsapp::SendOnWhatsappService,
    'Channel::Sms' => ::Sms::SendOnSmsService,
    'Channel::Instagram' => ::Instagram::SendOnInstagramService,
    'Channel::Tiktok' => ::Tiktok::SendOnTiktokService,
    'Channel::Email' => ::Email::SendOnEmailService,
    'Channel::WebWidget' => ::Messages::SendEmailNotificationService,
    'Channel::Api' => ::Messages::SendEmailNotificationService
  }.freeze

  def perform(message_id)
    message = message_id.is_a?(Message) ? message_id : Message.find_by(id: message_id)
    return unless message
    return if message.source_id.present?

    channel_name = message.conversation.inbox.channel.class.to_s

    Captain::Conversation::AgentMessageTranslationService.new(message: message).perform if message.content_attributes['translation_pending']

    return send_on_facebook_page(message) if channel_name == 'Channel::FacebookPage'

    service_class = CHANNEL_SERVICES[channel_name]
    return unless service_class

    service_class.new(message: message).perform
  end

  private

  def handle_whatsapp_failure(error, fallback_error)
    message = resolve_message
    return unless message
    return if message.source_id.present?

    if whatsapp_message?(message)
      message.update!(status: :failed, external_error: fallback_error)
    else
      raise error
    end
  end

  def resolve_message
    arg = arguments.first
    arg.is_a?(Message) ? arg : Message.find_by(id: arg)
  end

  def whatsapp_message?(message)
    message.conversation&.inbox&.channel_type == 'Channel::Whatsapp'
  end

  def send_on_facebook_page(message)
    if message.conversation.additional_attributes['type'] == 'instagram_direct_message'
      ::Instagram::Messenger::SendOnInstagramService.new(message: message).perform
    else
      ::Facebook::SendOnFacebookService.new(message: message).perform
    end
  end
end
