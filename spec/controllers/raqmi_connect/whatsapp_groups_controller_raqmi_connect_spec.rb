# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappGroupsController, type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account, phone_number: '+15551234567') }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: '15551234567') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact_inbox: contact_inbox) }
  let(:phone_id) { channel.provider_config['phone_number_id'] }

  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  describe 'POST /api/v1/accounts/:account_id/whatsapp_groups' do
    it 'creates a WhatsApp group via Meta Cloud API and returns invite link' do
      group_endpoint = "https://graph.facebook.com/v22.0/#{phone_id}/groups"
      invite_endpoint = 'https://graph.facebook.com/v22.0/120363099999999999@g.us/invite_link'

      stub_request(:post, group_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          subject: 'VIP Project Room',
          description: 'Support onboarding'
        }.to_json)
        .to_return(
          status: 200,
          body: {
            messaging_product: 'whatsapp',
            group: {
              id: '120363099999999999@g.us',
              subject: 'VIP Project Room'
            }
          }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      stub_request(:post, invite_endpoint)
        .to_return(
          status: 200,
          body: { invite_link: 'https://chat.whatsapp.com/AbC123Test' }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      post "/api/v1/accounts/#{account.id}/whatsapp_groups",
           params: {
             inbox_id: inbox.id,
             subject: 'VIP Project Room',
             description: 'Support onboarding'
           },
           headers: admin.create_new_auth_token

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['group_id']).to eq('120363099999999999@g.us')
      expect(json['subject']).to eq('VIP Project Room')
      expect(json['invite_link']).to eq('https://chat.whatsapp.com/AbC123Test')
      expect(json['conversation_id']).to be_present

      # Group conversation exists
      group_conv = Conversation.find(json['conversation_id'])
      expect(group_conv.additional_attributes['is_group']).to be(true)
    end

    it 'auto-invites the contact when auto_invite is true' do
      group_endpoint = "https://graph.facebook.com/v22.0/#{phone_id}/groups"
      invite_endpoint = 'https://graph.facebook.com/v22.0/120363099999999999@g.us/invite_link'
      messages_endpoint = "https://graph.facebook.com/v13.0/#{phone_id}/messages"

      stub_request(:post, group_endpoint)
        .to_return(
          status: 200,
          body: {
            messaging_product: 'whatsapp',
            group: { id: '120363099999999999@g.us', subject: 'VIP Project Room' }
          }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      stub_request(:post, invite_endpoint)
        .to_return(
          status: 200,
          body: { invite_link: 'https://chat.whatsapp.com/AbC123Test' }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      create(:message, conversation: conversation, message_type: :incoming, created_at: 1.minute.ago)

      stub_request(:post, messages_endpoint)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLInviteSent123' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      post "/api/v1/accounts/#{account.id}/whatsapp_groups",
           params: {
             inbox_id: inbox.id,
             subject: 'VIP Project Room',
             conversation_id: conversation.id,
             auto_invite: 'true'
           },
           headers: admin.create_new_auth_token

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['invited']).to be(true)

      last_msg = conversation.messages.last
      expect(last_msg.content).to include('https://chat.whatsapp.com/AbC123Test')
    end
  end
end
