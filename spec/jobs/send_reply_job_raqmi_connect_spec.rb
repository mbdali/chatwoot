# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

RSpec.describe SendReplyJob do
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
      message.update_column(:content_attributes, { 'dispatch_started_at' => Time.current.utc.iso8601 }) # rubocop:disable Rails/SkipsModelValidations

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
end
