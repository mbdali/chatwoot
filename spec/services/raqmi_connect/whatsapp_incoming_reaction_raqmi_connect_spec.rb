# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappIncomingReaction do
  let!(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let!(:inbox) { channel.inbox }
  let!(:contact) { create(:contact, phone_number: '+1234567890') }
  let!(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: '1234567890') }
  let!(:conversation) { create(:conversation, inbox: inbox, contact_inbox: contact_inbox, account: inbox.account) }
  let!(:target_message) do
    create(:message, account: inbox.account, inbox: inbox, conversation: conversation,
                     source_id: 'wamid.HBgLTargetMsg123', message_type: :outgoing)
  end

  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  describe '#perform' do
    it 'records an incoming emoji reaction on the target message content_attributes' do
      payload = {
        object: 'whatsapp_business_account',
        entry: [{
          id: '12345',
          changes: [{
            field: 'messages',
            value: {
              messaging_product: 'whatsapp',
              contacts: [{ wa_id: '1234567890', profile: { name: 'Customer One' } }],
              messages: [{
                from: '1234567890',
                id: 'wamid.HBgLReactionEvent1',
                timestamp: '1714152000',
                type: 'reaction',
                reaction: {
                  message_id: 'wamid.HBgLTargetMsg123',
                  emoji: '👍'
                }
              }]
            }
          }]
        }]
      }.with_indifferent_access

      service = Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload)
      service.perform

      reactions = target_message.reload.content_attributes['reactions']
      expect(reactions).to be_present
      expect(reactions.length).to eq(1)
      expect(reactions.first['emoji']).to eq('👍')
      expect(reactions.first['actor_type']).to eq('Contact')
      expect(reactions.first['actor_id']).to eq(contact.id)
    end

    it 'updates an existing reaction when customer sends a different emoji' do
      target_message.update!(content_attributes: {
        'reactions' => [{
          'emoji' => '👍',
          'actor_type' => 'Contact',
          'actor_id' => contact.id,
          'actor_name' => contact.name
        }]
      })

      payload = {
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            field: 'messages',
            value: {
              contacts: [{ wa_id: '1234567890', profile: { name: 'Customer One' } }],
              messages: [{
                from: '1234567890',
                id: 'wamid.HBgLReactionEvent2',
                timestamp: '1714152100',
                type: 'reaction',
                reaction: {
                  message_id: 'wamid.HBgLTargetMsg123',
                  emoji: '❤️'
                }
              }]
            }
          }]
        }]
      }.with_indifferent_access

      service = Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload)
      service.perform

      reactions = target_message.reload.content_attributes['reactions']
      expect(reactions.length).to eq(1)
      expect(reactions.first['emoji']).to eq('❤️')
    end

    it 'removes the reaction when emoji is empty' do
      target_message.update!(content_attributes: {
        'reactions' => [{
          'emoji' => '👍',
          'actor_type' => 'Contact',
          'actor_id' => contact.id,
          'actor_name' => contact.name
        }]
      })

      payload = {
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            field: 'messages',
            value: {
              contacts: [{ wa_id: '1234567890' }],
              messages: [{
                from: '1234567890',
                id: 'wamid.HBgLReactionEvent3',
                timestamp: '1714152200',
                type: 'reaction',
                reaction: {
                  message_id: 'wamid.HBgLTargetMsg123',
                  emoji: ''
                }
              }]
            }
          }]
        }]
      }.with_indifferent_access

      service = Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload)
      service.perform

      reactions = target_message.reload.content_attributes['reactions']
      expect(reactions).to be_empty
    end

    it 'records an outbound echo reaction from WhatsApp Business app' do
      payload = {
        entry: [{
          changes: [{
            field: 'smb_message_echoes',
            value: {
              contacts: [{ wa_id: '1234567890' }],
              message_echoes: [{
                from: channel.phone_number,
                to: '1234567890',
                id: 'wamid.HBgLEcho1',
                timestamp: '1714152300',
                type: 'reaction',
                reaction: {
                  message_id: 'wamid.HBgLTargetMsg123',
                  emoji: '🔥'
                }
              }]
            }
          }]
        }]
      }.with_indifferent_access

      service = Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: payload, outgoing_echo: true)
      service.perform

      reactions = target_message.reload.content_attributes['reactions']
      expect(reactions).to be_present
      expect(reactions.first['emoji']).to eq('🔥')
      expect(reactions.first['actor_type']).to eq('User')
    end
  end
end
