# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

RSpec.describe 'Conversation Messages API: Raqmi Connect retry guard', type: :request do
  let(:account) { create(:account) }

  describe 'POST /api/v1/accounts/{account.id}/conversations/:conversation_id/messages/:id/retry' do
    context 'when the message belongs to a WhatsApp inbox' do
      let!(:whatsapp_channel) do
        create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false, account: account)
      end
      let!(:whatsapp_inbox) { whatsapp_channel.inbox }
      let!(:whatsapp_conversation) { create(:conversation, inbox: whatsapp_inbox, account: account) }
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: whatsapp_inbox, user: agent)
      end

      it 'refuses retry when content_attributes has erp_outbox_id' do
        whatsapp_message = create(:message,
                                  account: account,
                                  conversation: whatsapp_conversation,
                                  status: :failed,
                                  content_attributes: { 'erp_outbox_id' => 'outbox_123', 'dispatch_started_at' => Time.current.utc.iso8601 },
                                  external_error: 'DISPATCH_NOT_SENT: Net::OpenTimeout')

        expect do
          post "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{whatsapp_message.id}/retry",
               headers: agent.create_new_auth_token,
               as: :json
        end.not_to have_enqueued_job(SendReplyJob)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('This message was sent by the ERP. Resend it from the ERP.')
        expect(whatsapp_message.reload.status).to eq('failed')
      end

      it 'refuses retry when external_error starts with DISPATCH_UNKNOWN:' do
        whatsapp_message = create(:message,
                                  account: account,
                                  conversation: whatsapp_conversation,
                                  status: :failed,
                                  content_attributes: { 'dispatch_started_at' => Time.current.utc.iso8601 },
                                  external_error: 'DISPATCH_UNKNOWN: Net::ReadTimeout: timed out')

        expect do
          post "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{whatsapp_message.id}/retry",
               headers: agent.create_new_auth_token,
               as: :json
        end.not_to have_enqueued_job(SendReplyJob)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Delivery status is unknown and the message may have been delivered. It cannot be retried.')
        expect(whatsapp_message.reload.status).to eq('failed')
      end

      it 'allows retry for DISPATCH_NOT_SENT message and clears source_id and dispatch_started_at' do
        whatsapp_message = create(:message,
                                  account: account,
                                  conversation: whatsapp_conversation,
                                  status: :failed,
                                  source_id: 'old_source_id',
                                  content_attributes: { 'dispatch_started_at' => Time.current.utc.iso8601, 'custom_attr' => 'kept' },
                                  external_error: 'DISPATCH_NOT_SENT: Net::OpenTimeout')

        expect do
          post "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{whatsapp_message.id}/retry",
               headers: agent.create_new_auth_token,
               as: :json
        end.to have_enqueued_job(SendReplyJob).with(whatsapp_message.id)

        expect(response).to have_http_status(:success)
        expect(whatsapp_message.reload.status).to eq('sent')
        expect(whatsapp_message.source_id).to be_nil
        expect(whatsapp_message.content_attributes['dispatch_started_at']).to be_nil
        expect(whatsapp_message.content_attributes['custom_attr']).to eq('kept')
        expect(whatsapp_message.external_error).to be_nil
      end

      it 'allows retry for Meta-refused message and clears source_id and dispatch_started_at' do
        whatsapp_message = create(:message,
                                  account: account,
                                  conversation: whatsapp_conversation,
                                  status: :failed,
                                  source_id: 'old_source_id',
                                  content_attributes: { 'dispatch_started_at' => Time.current.utc.iso8601 },
                                  external_error: '(#100) Param name is invalid')

        expect do
          post "/api/v1/accounts/#{account.id}/conversations/#{whatsapp_conversation.display_id}/messages/#{whatsapp_message.id}/retry",
               headers: agent.create_new_auth_token,
               as: :json
        end.to have_enqueued_job(SendReplyJob).with(whatsapp_message.id)

        expect(response).to have_http_status(:success)
        expect(whatsapp_message.reload.status).to eq('sent')
        expect(whatsapp_message.source_id).to be_nil
        expect(whatsapp_message.content_attributes['dispatch_started_at']).to be_nil
        expect(whatsapp_message.external_error).to be_nil
      end
    end
  end
end
