# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappCloudGroupDispatch do
  let!(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let!(:inbox) { channel.inbox }
  let!(:contact) { create(:contact, additional_attributes: { 'is_group' => true, 'group_id' => '120363012345678901@g.us' }) }
  let!(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: '120363012345678901@g.us') }
  let!(:conversation) do
    create(:conversation, inbox: inbox, contact_inbox: contact_inbox, account: inbox.account,
                          additional_attributes: { 'is_group' => true, 'group_id' => '120363012345678901@g.us' })
  end
  let(:messages_endpoint) { "https://graph.facebook.com/v13.0/#{channel.provider_config['phone_number_id']}/messages" }

  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  describe '#send_text_message to a group' do
    it 'dispatches text message with recipient_type: group and to: group_id' do
      message = create(:message, account: inbox.account, inbox: inbox, conversation: conversation,
                                 message_type: :outgoing, content: 'Hello everyone in group')

      stub_request(:post, messages_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          recipient_type: 'group',
          to: '120363012345678901@g.us',
          text: { body: 'Hello everyone in group' },
          type: 'text'
        }.to_json)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLGroupMsg123' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      result = channel.send_message('120363012345678901@g.us', message)
      expect(result).to eq('wamid.HBgLGroupMsg123')
    end
  end

  describe '#send_template to a group' do
    it 'dispatches template with recipient_type: group' do
      message = create(:message, account: inbox.account, inbox: inbox, conversation: conversation,
                                 message_type: :outgoing)

      template_info = {
        name: 'sample_group_template',
        namespace: 'sample_namespace',
        lang_code: 'en_US',
        parameters: ['Welcome']
      }

      stub_request(:post, messages_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          recipient_type: 'group',
          to: '120363012345678901@g.us',
          type: 'template',
          template: {
            name: 'sample_group_template',
            language: { code: 'en_US', policy: 'deterministic' },
            components: [{
              type: 'body',
              parameters: [{ type: 'text', text: 'Welcome' }]
            }]
          }
        }.to_json)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLGroupTemplateMsg123' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      result = channel.send_template('120363012345678901@g.us', template_info, message)
      expect(result).to eq('wamid.HBgLGroupTemplateMsg123')
    end
  end

  describe '#send_interactive_text_message to a group' do
    it 'converts interactive options to formatted plain text to adhere to Meta group limits' do
      message = create(:message, account: inbox.account, inbox: inbox, conversation: conversation,
                                 message_type: :outgoing, content_type: 'input_select',
                                 content: 'Please choose an option:',
                                 content_attributes: {
                                   items: [
                                     { title: 'Billing', value: 'billing' },
                                     { title: 'Tech Support', value: 'tech' }
                                   ]
                                 })

      stub_request(:post, messages_endpoint)
        .with(body: {
          messaging_product: 'whatsapp',
          recipient_type: 'group',
          to: '120363012345678901@g.us',
          text: { body: "Please choose an option:\n\n1. Billing\n2. Tech Support" },
          type: 'text'
        }.to_json)
        .to_return(
          status: 200,
          body: { messages: [{ id: 'wamid.HBgLGroupInteractiveFallback123' }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        )

      result = channel.send_message('120363012345678901@g.us', message)
      expect(result).to eq('wamid.HBgLGroupInteractiveFallback123')
    end
  end
end
