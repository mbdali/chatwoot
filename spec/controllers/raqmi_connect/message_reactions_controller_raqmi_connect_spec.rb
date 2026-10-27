# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

RSpec.describe 'Message Reactions API: Raqmi Connect', type: :request do
  let(:account) { create(:account) }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false, account: account)
  end
  let!(:whatsapp_inbox) { whatsapp_channel.inbox }
  let!(:contact) { create(:contact, account: account, phone_number: '+1234567890') }
  let!(:contact_inbox) { create(:contact_inbox, inbox: whatsapp_inbox, contact: contact, source_id: '1234567890') }
  let!(:whatsapp_conversation) { create(:conversation, inbox: whatsapp_inbox, contact_inbox: contact_inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:messages_endpoint) { "https://graph.facebook.com/v13.0/#{whatsapp_channel.provider_config['phone_number_id']}/messages" }

  before do
    create(:inbox_member, inbox: whatsapp_inbox, user: agent)
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
    # Create an incoming message so can_reply? is true
    create(:message, conversation: whatsapp_conversation, account: account, message_type: :incoming, created_at: Time.current)
  end

  describe 'POST /api/v1/accounts/:account_id/conversations/:conversation_id/messages/:id/reaction' do
    let!(:whatsapp_message) do
      create(:message, account: account, conversation: whatsapp_conversation,
                       source_id: 'wamid.HBgLTargetMsg456', message_type: :incoming)
    end

    it 'successfully posts reaction to WhatsApp and saves reaction on message' do
      stub_request(:post, messages_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: '1234567890',
          type: 'reaction',
          reaction: {
            message_id: 'wamid.HBgLTargetMsg456',
            emoji: '🔥'
          }
        }.to_json)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLReactionSent789' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      post "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{whatsapp_message.id}/reaction",
           params: { emoji: '🔥' },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['reactions']).to be_present
      expect(response.parsed_body['reactions'].first['emoji']).to eq('🔥')
      expect(response.parsed_body['reactions'].first['actor_id']).to eq(agent.id)

      reactions = whatsapp_message.reload.content_attributes['reactions']
      expect(reactions.first['emoji']).to eq('🔥')
      expect(reactions.first['actor_id']).to eq(agent.id)
    end

    it 'returns unprocessable_entity if emoji is blank' do
      post "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{whatsapp_message.id}/reaction",
           params: { emoji: ' ' },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Emoji cannot be blank.')
    end

    it 'returns unprocessable_entity if message has no WhatsApp source_id' do
      unsent_message = create(:message, account: account, conversation: whatsapp_conversation,
                                        source_id: nil, message_type: :outgoing)

      post "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{unsent_message.id}/reaction",
           params: { emoji: '👍' },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Cannot react to a message without a WhatsApp message ID.')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/conversations/:conversation_id/messages/:id/reaction' do
    let!(:whatsapp_message) do
      create(:message, account: account, conversation: whatsapp_conversation,
                       source_id: 'wamid.HBgLTargetMsg456', message_type: :incoming,
                       content_attributes: {
                         'reactions' => [{
                           'emoji' => '👍',
                           'actor_type' => 'User',
                           'actor_id' => agent.id,
                           'actor_name' => agent.name
                         }]
                       })
    end

    it 'removes agent reaction and dispatches empty emoji to Meta' do
      stub_request(:post, messages_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: '1234567890',
          type: 'reaction',
          reaction: {
            message_id: 'wamid.HBgLTargetMsg456',
            emoji: ''
          }
        }.to_json)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLReactionRemoveSuccess' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      delete "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{whatsapp_message.id}/reaction",
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['reactions']).to be_empty
      expect(whatsapp_message.reload.content_attributes['reactions']).to be_empty
    end
  end
end
