# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappCloudReactions do
  let!(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:messages_endpoint) { "https://graph.facebook.com/v13.0/#{channel.provider_config['phone_number_id']}/messages" }

  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  describe '#send_reaction' do
    it 'posts reaction payload to Meta Graph API and returns message id' do
      stub_request(:post, messages_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: '1234567890',
          type: 'reaction',
          reaction: {
            message_id: 'wamid.HBgLTarget123',
            emoji: '👍'
          }
        }.to_json)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLReactionId999' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      result = channel.send_reaction('1234567890', 'wamid.HBgLTarget123', '👍')
      expect(result).to eq('wamid.HBgLReactionId999')
    end

    it 'posts empty emoji string when removing reaction' do
      stub_request(:post, messages_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: '1234567890',
          type: 'reaction',
          reaction: {
            message_id: 'wamid.HBgLTarget123',
            emoji: ''
          }
        }.to_json)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLReactionRemoveId' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      result = channel.send_reaction('1234567890', 'wamid.HBgLTarget123', '')
      expect(result).to eq('wamid.HBgLReactionRemoveId')
    end

    it 'raises CustomExceptions::WhatsappReactionError when Meta returns an error' do
      stub_request(:post, messages_endpoint)
        .to_return(
          status: 400,
          body: { error: { message: 'Message too old to react', code: 131051 } }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      expect do
        channel.send_reaction('1234567890', 'wamid.HBgLTarget123', '👍')
      end.to raise_error(CustomExceptions::WhatsappReactionError, /Message too old to react/)
    end
  end
end
