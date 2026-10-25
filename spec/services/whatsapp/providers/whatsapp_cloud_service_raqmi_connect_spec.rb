# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:conversation) { create(:conversation, inbox: whatsapp_channel.inbox) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:message) do
    create(:message, conversation: conversation, message_type: :outgoing, content: 'test', inbox: whatsapp_channel.inbox, source_id: 'external_id')
  end

  describe '#handle_error' do
    before do
      allow(Rails.logger).to receive(:error)
    end

    context 'when HTTP response is 5xx' do
      let(:server_error_response_object) do
        instance_double(
          HTTParty::Response,
          code: 502,
          body: 'Bad Gateway',
          parsed_response: {}
        )
      end

      it 'records DISPATCH_UNKNOWN: HTTP <code>' do
        service.instance_variable_set(:@message, message)
        service.send(:handle_error, server_error_response_object, message)

        expect(message.reload.status).to eq('failed')
        expect(message.reload.external_error).to eq('DISPATCH_UNKNOWN: HTTP 502')
      end
    end
  end
end
