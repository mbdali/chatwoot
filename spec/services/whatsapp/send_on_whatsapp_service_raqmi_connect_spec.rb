# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe Whatsapp::SendOnWhatsappService do
  describe '#perform' do
    before do
      stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
      stub_request(:post, 'https://waba.360dialog.io/v1/messages')
    end

    context 'when dispatch marker and error classification are evaluated' do
      let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
      let!(:contact_inbox) { create(:contact_inbox, inbox: whatsapp_channel.inbox, source_id: '123456789') }
      let!(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: whatsapp_channel.inbox) }
      let(:messages_endpoint) { "https://graph.facebook.com/v13.0/#{whatsapp_channel.provider_config['phone_number_id']}/messages" }

      before do
        stub_request(:post, "https://graph.facebook.com/v14.0/#{whatsapp_channel.provider_config['business_account_id']}/message_templates")
        create(:message, message_type: :incoming, content: 'incoming message',
                         conversation: conversation, account: conversation.account)
      end

      it 'saves dispatch_started_at in UTC ISO-8601 into content_attributes before calling Meta' do
        message = create(:message, message_type: :outgoing, content: 'hello',
                                   conversation: conversation, account: conversation.account)

        stub_request(:post, messages_endpoint)
          .to_return do |_request|
            expect(message.reload.content_attributes['dispatch_started_at']).to be_present
            expect { Time.iso8601(message.content_attributes['dispatch_started_at']) }.not_to raise_error
            {
              status: 200,
              body: { 'messages' => [{ 'id' => 'wamid_12345' }] }.to_json,
              headers: { 'content-type' => 'application/json' }
            }
          end

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).to have_been_made.once
        expect(message.reload.source_id).to eq('wamid_12345')
        expect(message.content_attributes['dispatch_started_at']).to be_present
      end

      it 'makes exactly one HTTP request when two service instances run for the same message and the second sees the marker the first wrote' do
        message = create(:message, message_type: :outgoing, content: 'hello',
                                   conversation: conversation, account: conversation.account)

        service_one = described_class.new(message: message)
        service_two = described_class.new(message: Message.find(message.id))

        stub_request(:post, messages_endpoint)
          .to_return do |_request|
            service_two.perform
            {
              status: 200,
              body: { 'messages' => [{ 'id' => 'wamid_12345' }] }.to_json,
              headers: { 'content-type' => 'application/json' }
            }
          end

        service_one.perform

        expect(a_request(:post, messages_endpoint)).to have_been_made.once
        expect(message.reload.source_id).to eq('wamid_12345')
      end

      it 'does not send and marks failed DISPATCH_UNKNOWN when dispatch_started_at is present and source_id is blank' do
        message = create(:message, message_type: :outgoing, content: 'hello',
                                   conversation: conversation, account: conversation.account,
                                   content_attributes: { 'dispatch_started_at' => Time.current.utc.iso8601 },
                                   source_id: nil)

        stub_request(:post, messages_endpoint)

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).not_to have_been_made
        expect(message.reload.status).to eq('failed')
        expect(message.reload.external_error).to eq('DISPATCH_UNKNOWN: interrupted dispatch')
      end

      it 'does not mark failed if message.source_id is already present' do
        message = create(:message, message_type: :outgoing, content: 'hello',
                                   conversation: conversation, account: conversation.account,
                                   source_id: 'existing_id')

        stub_request(:post, messages_endpoint)

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).not_to have_been_made
        expect(message.reload.status).not_to eq('failed')
      end

      [
        Net::OpenTimeout,
        Errno::ECONNREFUSED,
        SocketError
      ].each do |exception_class|
        it "classifies connection error after marker as DISPATCH_NOT_SENT and removes marker for #{exception_class}" do
          message = create(:message, message_type: :outgoing, content: 'hello',
                                     conversation: conversation, account: conversation.account)

          stub_request(:post, messages_endpoint).to_raise(exception_class.new('connection failed'))

          described_class.new(message: message).perform

          expect(a_request(:post, messages_endpoint)).to have_been_made.once
          expect(message.reload.status).to eq('failed')
          expect(message.reload.external_error).to eq("DISPATCH_NOT_SENT: #{exception_class}")
          expect(message.reload.content_attributes['dispatch_started_at']).to be_blank
        end
      end

      [
        Net::ReadTimeout,
        Errno::ECONNRESET,
        Timeout::Error
      ].each do |exception_class|
        it "classifies read/reset error after marker as DISPATCH_UNKNOWN and keeps marker for #{exception_class}" do
          message = create(:message, message_type: :outgoing, content: 'hello',
                                     conversation: conversation, account: conversation.account)

          stub_request(:post, messages_endpoint).to_raise(exception_class.new('network timeout after send'))

          described_class.new(message: message).perform

          expect(a_request(:post, messages_endpoint)).to have_been_made.once
          expect(message.reload.status).to eq('failed')
          expect(message.reload.external_error).to start_with("DISPATCH_UNKNOWN: #{exception_class}:")
          expect(message.reload.content_attributes['dispatch_started_at']).to be_present
        end
      end

      it 'classifies exception before the HTTP call as DISPATCH_NOT_SENT with zero HTTP calls' do
        message = create(:message, message_type: :outgoing, content: 'hello',
                                   conversation: conversation, account: conversation.account)

        stub_request(:post, messages_endpoint)
        allow(conversation).to receive(:can_reply?).and_raise(StandardError.new('pre-dispatch validation failure'))

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).not_to have_been_made
        expect(message.reload.status).to eq('failed')
        expect(message.reload.external_error).to eq('DISPATCH_NOT_SENT: StandardError: pre-dispatch validation failure')
        expect(message.reload.content_attributes['dispatch_started_at']).to be_blank
      end

      it 'performs dispatch twice for an interrupted run making exactly one HTTP call in total and marking interrupted dispatch' do
        message = create(:message, message_type: :outgoing, content: 'hello',
                                   conversation: conversation, account: conversation.account)

        stub_request(:post, messages_endpoint).to_raise(Net::ReadTimeout.new('timed out'))

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).to have_been_made.once
        expect(message.reload.status).to eq('failed')
        expect(message.reload.content_attributes['dispatch_started_at']).to be_present

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).to have_been_made.once
        expect(message.reload.status).to eq('failed')
        expect(message.reload.external_error).to eq('DISPATCH_UNKNOWN: interrupted dispatch')
      end

      it 'sends one request and re-run sends nothing when Meta returns wamid but message.update! raises' do
        message = create(:message, message_type: :outgoing, content: 'hello',
                                   conversation: conversation, account: conversation.account)

        stub_request(:post, messages_endpoint)
          .to_return(status: 200, body: { 'messages' => [{ 'id' => 'wamid_12345' }] }.to_json,
                     headers: { 'content-type' => 'application/json' })

        allow(message).to receive(:update!).and_call_original
        allow(message).to receive(:update!).with(source_id: 'wamid_12345').and_raise(ActiveRecord::StatementInvalid.new('PG error'))

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).to have_been_made.once
        expect(message.reload.source_id).to be_nil
        expect(message.reload.content_attributes['dispatch_started_at']).to be_present
        expect(message.reload.external_error).to start_with('DISPATCH_UNKNOWN: ActiveRecord::StatementInvalid:')

        described_class.new(message: message).perform

        expect(a_request(:post, messages_endpoint)).to have_been_made.once
        expect(message.reload.external_error).to eq('DISPATCH_UNKNOWN: interrupted dispatch')
      end
    end
  end
end
