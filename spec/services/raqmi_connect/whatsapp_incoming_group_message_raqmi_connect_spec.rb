# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappIncomingGroupMessage do
  let!(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let!(:inbox) { channel.inbox }

  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  describe 'incoming group messages' do
    it 'creates a group contact, routes messages to the group conversation, and prefixes sender name' do
      payload = {
        object: 'whatsapp_business_account',
        entry: [{
          id: '12345',
          changes: [{
            field: 'messages',
            value: {
              messaging_product: 'whatsapp',
              contacts: [{ wa_id: '15551234567', profile: { name: 'Alice Walker' } }],
              messages: [{
                from: '15551234567',
                group_id: '120363098765432101@g.us',
                group_name: 'VIP Project Room',
                id: 'wamid.HBgLGroupInbound1',
                timestamp: '1714152000',
                type: 'text',
                text: { body: 'Hello group from Alice!' }
              }]
            }
          }]
        }]
      }.with_indifferent_access

      service = Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload)
      service.perform

      # Verifies group contact created
      contact = Contact.find_by(name: 'VIP Project Room')
      expect(contact).to be_present
      expect(contact.additional_attributes['is_group']).to be(true)
      expect(contact.additional_attributes['group_id']).to eq('120363098765432101@g.us')

      contact_inbox = inbox.contact_inboxes.find_by(source_id: '120363098765432101@g.us')
      expect(contact_inbox).to be_present

      # Verifies conversation created
      conversation = contact_inbox.conversations.last
      expect(conversation).to be_present
      expect(conversation.additional_attributes['is_group']).to be(true)

      # Verifies message content is prefixed with sender name and metadata is recorded
      message = conversation.messages.last
      expect(message.content).to eq('[Alice Walker]: Hello group from Alice!')
      expect(message.content_attributes['is_group']).to be(true)
      expect(message.content_attributes['group_sender']).to eq({
        'name' => 'Alice Walker',
        'phone_number' => '15551234567'
      })
    end

    it 'routes subsequent messages from a different participant to the SAME group conversation' do
      group_id = '120363098765432101@g.us'

      # Message 1 from Alice
      payload_alice = {
        object: 'whatsapp_business_account',
        entry: [{
          id: '12345',
          changes: [{
            field: 'messages',
            value: {
              messaging_product: 'whatsapp',
              contacts: [{ wa_id: '15551111111', profile: { name: 'Alice' } }],
              messages: [{
                from: '15551111111',
                group_id: group_id,
                id: 'wamid.Msg1',
                timestamp: '1714152000',
                type: 'text',
                text: { body: 'First message' }
              }]
            }
          }]
        }]
      }.with_indifferent_access
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload_alice).perform

      # Message 2 from Bob
      payload_bob = {
        object: 'whatsapp_business_account',
        entry: [{
          id: '12345',
          changes: [{
            field: 'messages',
            value: {
              messaging_product: 'whatsapp',
              contacts: [{ wa_id: '15552222222', profile: { name: 'Bob' } }],
              messages: [{
                from: '15552222222',
                group_id: group_id,
                id: 'wamid.Msg2',
                timestamp: '1714152005',
                type: 'text',
                text: { body: 'Second message' }
              }]
            }
          }]
        }]
      }.with_indifferent_access
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload_bob).perform

      # Verifies both messages belong to the EXACT same conversation
      contact_inbox = inbox.contact_inboxes.find_by(source_id: group_id)
      conversation = contact_inbox.conversations.last
      expect(conversation.messages.pluck(:content)).to eq([
        '[Alice]: First message',
        '[Bob]: Second message'
      ])
    end
  end

  describe 'group lifecycle webhooks' do
    it 'creates a group contact, conversation, and activity message on group_create' do
      payload = {
        object: 'whatsapp_business_account',
        entry: [{
          id: '12345',
          changes: [{
            field: 'group_lifecycle_update',
            value: {
              messaging_product: 'whatsapp',
              groups: [{
                group_id: '120363055555555555@g.us',
                type: 'group_create',
                subject: 'Deal Room Alpha',
                invite_link: 'https://chat.whatsapp.com/TestLink123'
              }]
            }
          }]
        }]
      }.with_indifferent_access

      service = Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload)
      service.perform

      contact = Contact.find_by(name: 'Deal Room Alpha')
      expect(contact).to be_present
      expect(contact.additional_attributes['invite_link']).to eq('https://chat.whatsapp.com/TestLink123')

      contact_inbox = inbox.contact_inboxes.find_by(source_id: '120363055555555555@g.us')
      conversation = contact_inbox.conversations.last
      expect(conversation).to be_present

      activity_msg = conversation.messages.last
      expect(activity_msg.message_type).to eq('activity')
      expect(activity_msg.content).to include('WhatsApp group created: Deal Room Alpha')
    end
  end

  describe 'group participants webhooks' do
    it 'creates an activity message when a participant joins' do
      group_id = '120363055555555555@g.us'

      payload = {
        object: 'whatsapp_business_account',
        entry: [{
          id: '12345',
          changes: [{
            field: 'group_participants_update',
            value: {
              messaging_product: 'whatsapp',
              group: { id: group_id },
              event: 'JOIN',
              participants: [{ wa_id: '15559998888' }]
            }
          }]
        }]
      }.with_indifferent_access

      service = Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload)
      service.perform

      contact_inbox = inbox.contact_inboxes.find_by(source_id: group_id)
      conversation = contact_inbox.conversations.last
      expect(conversation).to be_present

      activity_msg = conversation.messages.last
      expect(activity_msg.message_type).to eq('activity')
      expect(activity_msg.content).to eq('15559998888 joined the group.')
    end
  end
end
