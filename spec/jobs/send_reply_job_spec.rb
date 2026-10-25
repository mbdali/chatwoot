require 'rails_helper'

RSpec.describe SendReplyJob do
  subject(:job) { described_class.perform_later(message) }

  let(:message) { create(:message) }

  it 'enqueues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(message)
      .on_queue('high')
  end

  context 'when the job is triggered on a new message' do
    let(:process_service) { double }

    before do
      allow(process_service).to receive(:perform)
    end

    def expect_mapped_service_to_perform(message, service_class_name)
      channel_name = message.conversation.inbox.channel.class.name
      service_class = described_class::CHANNEL_SERVICES.fetch(channel_name)

      expect(service_class.name).to eq(service_class_name)
      expect(service_class).to receive(:new).with(message: message).and_return(process_service)
      expect(process_service).to receive(:perform)

      described_class.perform_now(message.id)
    end

    it 'calls Facebook::SendOnFacebookService when its facebook message' do
      stub_request(:post, /graph.facebook.com/)
      facebook_channel = create(:channel_facebook_page)
      facebook_inbox = create(:inbox, channel: facebook_channel)
      message = create(:message, conversation: create(:conversation, inbox: facebook_inbox))
      allow(Facebook::SendOnFacebookService).to receive(:new).with(message: message).and_return(process_service)
      expect(Facebook::SendOnFacebookService).to receive(:new).with(message: message)
      expect(process_service).to receive(:perform)
      described_class.perform_now(message.id)
    end

    it 'calls ::Twitter::SendOnTwitterService when its twitter message' do
      twitter_channel = create(:channel_twitter_profile)
      twitter_inbox = create(:inbox, channel: twitter_channel)
      message = create(:message, conversation: create(:conversation, inbox: twitter_inbox))
      expect_mapped_service_to_perform(message, 'Twitter::SendOnTwitterService')
    end

    it 'calls ::Twilio::SendOnTwilioService when its twilio message' do
      twilio_channel = create(:channel_twilio_sms)
      message = create(:message, conversation: create(:conversation, inbox: twilio_channel.inbox))
      expect_mapped_service_to_perform(message, 'Twilio::SendOnTwilioService')
    end

    it 'calls ::Telegram::SendOnTelegramService when its telegram message' do
      telegram_channel = create(:channel_telegram)
      message = create(:message, conversation: create(:conversation, inbox: telegram_channel.inbox))
      expect_mapped_service_to_perform(message, 'Telegram::SendOnTelegramService')
    end

    it 'calls ::Line:SendOnLineService when its line message' do
      line_channel = create(:channel_line)
      message = create(:message, conversation: create(:conversation, inbox: line_channel.inbox))
      expect_mapped_service_to_perform(message, 'Line::SendOnLineService')
    end

    it 'calls ::Whatsapp:SendOnWhatsappService when its whatsapp message' do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
      whatsapp_channel = create(:channel_whatsapp, sync_templates: false)
      message = create(:message, conversation: create(:conversation, inbox: whatsapp_channel.inbox))
      expect_mapped_service_to_perform(message, 'Whatsapp::SendOnWhatsappService')
    end

    it 'calls ::Sms::SendOnSmsService when its sms message' do
      sms_channel = create(:channel_sms)
      message = create(:message, conversation: create(:conversation, inbox: sms_channel.inbox))
      expect_mapped_service_to_perform(message, 'Sms::SendOnSmsService')
    end

    it 'calls ::Instagram::Direct::SendOnInstagramService when its instagram message' do
      instagram_channel = create(:channel_instagram)
      message = create(:message, conversation: create(:conversation, inbox: instagram_channel.inbox))
      expect_mapped_service_to_perform(message, 'Instagram::SendOnInstagramService')
    end

    it 'calls ::Instagram::Messenger::SendOnInstagramService when its an instagram_direct_message from facebook channel' do
      stub_request(:post, /graph.facebook.com/)
      facebook_channel = create(:channel_facebook_page)
      facebook_inbox = create(:inbox, channel: facebook_channel)
      conversation = create(:conversation,
                            inbox: facebook_inbox,
                            additional_attributes: { 'type' => 'instagram_direct_message' })
      message = create(:message, conversation: conversation)

      allow(Instagram::Messenger::SendOnInstagramService).to receive(:new).with(message: message).and_return(process_service)
      expect(Instagram::Messenger::SendOnInstagramService).to receive(:new).with(message: message)
      expect(process_service).to receive(:perform)
      described_class.perform_now(message.id)
    end

    it 'calls ::Email::SendOnEmailService when its email message' do
      email_channel = create(:channel_email)
      message = create(:message, conversation: create(:conversation, inbox: email_channel.inbox))
      expect_mapped_service_to_perform(message, 'Email::SendOnEmailService')
    end

    it 'calls ::Messages::SendEmailNotificationService when its webwidget message' do
      webwidget_channel = create(:channel_widget)
      message = create(:message, conversation: create(:conversation, inbox: webwidget_channel.inbox))
      expect_mapped_service_to_perform(message, 'Messages::SendEmailNotificationService')
    end

    it 'calls ::Messages::SendEmailNotificationService when its api channel message' do
      api_channel = create(:channel_api)
      message = create(:message, conversation: create(:conversation, inbox: api_channel.inbox))
      expect_mapped_service_to_perform(message, 'Messages::SendEmailNotificationService')
    end

    it 'calls ::Tiktok::SendOnTiktokService when its tiktok message' do
      tiktok_channel = create(:channel_tiktok)
      message = create(:message, conversation: create(:conversation, inbox: tiktok_channel.inbox))
      expect_mapped_service_to_perform(message, 'Tiktok::SendOnTiktokService')
    end
  end

  context 'when dispatching on WhatsApp' do
    let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
    let!(:contact_inbox) { create(:contact_inbox, inbox: whatsapp_channel.inbox, source_id: '123456789') }
    let!(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: whatsapp_channel.inbox) }
    let(:messages_endpoint) { "https://graph.facebook.com/v13.0/#{whatsapp_channel.provider_config['phone_number_id']}/messages" }
    let(:message) do
      create(:message, message_type: :outgoing, content: 'Test reply',
                       conversation: conversation, account: conversation.account)
    end

    before do
      stub_request(:post, "https://graph.facebook.com/v14.0/#{whatsapp_channel.provider_config['business_account_id']}/message_templates")
      create(:message, message_type: :incoming, content: 'incoming message',
                       conversation: conversation, account: conversation.account)
    end

    it 'runs SendReplyJob twice for one message and makes exactly one HTTP call on success path' do
      stub_request(:post, messages_endpoint)
        .to_return(status: 200, body: { 'messages' => [{ 'id' => 'wamid_12345' }] }.to_json,
                   headers: { 'content-type' => 'application/json' })

      described_class.perform_now(message.id)
      described_class.perform_now(message.id)

      expect(a_request(:post, messages_endpoint)).to have_been_made.once
      expect(message.reload.source_id).to eq('wamid_12345')
      expect(message.content_attributes['dispatch_started_at']).to be_present
    end

    it 'sets the marker on a message with no source_id and checks zero HTTP calls and DISPATCH_UNKNOWN' do
      message.update_column(:content_attributes, { 'dispatch_started_at' => Time.now.utc.iso8601 })

      stub_request(:post, messages_endpoint)

      described_class.perform_now(message.id)

      expect(a_request(:post, messages_endpoint)).not_to have_been_made
      expect(message.reload.status).to eq('failed')
      expect(message.reload.external_error).to eq('DISPATCH_UNKNOWN: interrupted dispatch')
    end

    [
      Net::OpenTimeout,
      Errno::ECONNREFUSED,
      SocketError
    ].each do |exception_class|
      context "with connection exception #{exception_class}" do
        it 'stubs exception after marker, checks DISPATCH_NOT_SENT, removes marker, exactly one HTTP call and no re-enqueue' do
          stub_request(:post, messages_endpoint).to_raise(exception_class.new('network failed'))

          expect do
            described_class.perform_now(message.id)
          end.not_to have_enqueued_job(described_class)

          expect(a_request(:post, messages_endpoint)).to have_been_made.once
          expect(message.reload.status).to eq('failed')
          expect(message.reload.external_error).to eq("DISPATCH_NOT_SENT: #{exception_class}")
          expect(message.reload.content_attributes['dispatch_started_at']).to be_blank
        end
      end
    end

    [
      Net::ReadTimeout,
      Errno::ECONNRESET,
      Timeout::Error
    ].each do |exception_class|
      context "with post-handshake exception #{exception_class}" do
        it 'stubs exception after marker, checks DISPATCH_UNKNOWN prefix, keeps marker, exactly one HTTP call and no re-enqueue' do
          stub_request(:post, messages_endpoint).to_raise(exception_class.new('network failed'))

          expect do
            described_class.perform_now(message.id)
          end.not_to have_enqueued_job(described_class)

          expect(a_request(:post, messages_endpoint)).to have_been_made.once
          expect(message.reload.status).to eq('failed')
          expect(message.reload.external_error).to start_with("DISPATCH_UNKNOWN: #{exception_class}:")
          expect(message.reload.content_attributes['dispatch_started_at']).to be_present
        end
      end
    end

    it 'stubs exception before the marker and checks DISPATCH_NOT_SENT prefix, zero HTTP calls and no re-enqueue' do
      stub_request(:post, messages_endpoint)
      allow(conversation).to receive(:can_reply?).and_raise(StandardError.new('pre-dispatch failed'))

      expect do
        described_class.perform_now(message.id)
      end.not_to have_enqueued_job(described_class)

      expect(a_request(:post, messages_endpoint)).not_to have_been_made
      expect(message.reload.status).to eq('failed')
      expect(message.reload.external_error).to eq('DISPATCH_NOT_SENT: StandardError: pre-dispatch failed')
      expect(message.reload.content_attributes['dispatch_started_at']).to be_blank
    end

    it 'performs job twice for the same message where first run wrote marker and raised, making one HTTP call in total' do
      stub_request(:post, messages_endpoint).to_raise(Net::ReadTimeout.new('network timeout'))

      described_class.perform_now(message.id)

      expect(a_request(:post, messages_endpoint)).to have_been_made.once
      expect(message.reload.status).to eq('failed')
      expect(message.reload.content_attributes['dispatch_started_at']).to be_present

      described_class.perform_now(message.id)

      expect(a_request(:post, messages_endpoint)).to have_been_made.once
      expect(message.reload.status).to eq('failed')
      expect(message.reload.external_error).to eq('DISPATCH_UNKNOWN: interrupted dispatch')
    end

    it 'makes one request when Meta returns wamid but message.update! raises, and re-run sends nothing' do
      stub_request(:post, messages_endpoint)
        .to_return(status: 200, body: { 'messages' => [{ 'id' => 'wamid_12345' }] }.to_json,
                   headers: { 'content-type' => 'application/json' })

      allow(Message).to receive(:find_by).and_call_original
      allow(Message).to receive(:find_by).with(id: message.id).and_return(message)
      allow(message).to receive(:update!).and_call_original
      allow(message).to receive(:update!).with(source_id: 'wamid_12345').and_raise(ActiveRecord::StatementInvalid.new('DB failure'))

      described_class.perform_now(message.id)

      expect(a_request(:post, messages_endpoint)).to have_been_made.once
      expect(message.reload.source_id).to be_nil
      expect(message.reload.content_attributes['dispatch_started_at']).to be_present
      expect(message.reload.external_error).to start_with('DISPATCH_UNKNOWN: ActiveRecord::StatementInvalid:')

      described_class.perform_now(message.id)

      expect(a_request(:post, messages_endpoint)).to have_been_made.once
      expect(message.reload.external_error).to eq('DISPATCH_UNKNOWN: interrupted dispatch')
    end
end
