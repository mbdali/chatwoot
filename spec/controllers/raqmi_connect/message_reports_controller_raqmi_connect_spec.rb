# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

RSpec.describe 'Message Reports API: Raqmi Connect', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before do
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :incoming, created_at: 1.day.ago)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, status: :delivered, created_at: 1.day.ago)
  end

  describe 'GET /api/v1/accounts/:account_id/reports/messages' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/reports/messages"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      it 'returns incoming and outgoing volume and delivery rate' do
        get "/api/v1/accounts/#{account.id}/reports/messages",
            params: {
              since: 7.days.ago.to_i.to_s,
              until: Time.current.to_i.to_s,
              group_by: 'day'
            },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        json = response.parsed_body

        expect(json['incoming']['total']).to eq(1)
        expect(json['outgoing']['total']).to eq(1)
        expect(json['outgoing']['delivery_rate']).to eq(100.0)
      end

      it 'returns chart series and categories' do
        get "/api/v1/accounts/#{account.id}/reports/messages",
            params: {
              since: 7.days.ago.to_i.to_s,
              until: Time.current.to_i.to_s,
              group_by: 'day'
            },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        json = response.parsed_body

        expect(json['incoming']['chart_data']['series']).to be_an(Array)
        expect(json['outgoing']['chart_data']['series']).to be_an(Array)
      end

      it 'filters by inbox when inbox_id is supplied' do
        other_inbox = create(:inbox, account: account)
        other_conv = create(:conversation, account: account, inbox: other_inbox)
        create(:message, account: account, inbox: other_inbox, conversation: other_conv,
                         message_type: :incoming, created_at: 1.day.ago)

        get "/api/v1/accounts/#{account.id}/reports/messages",
            params: {
              since: 7.days.ago.to_i.to_s,
              until: Time.current.to_i.to_s,
              inbox_id: inbox.id
            },
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['incoming']['total']).to eq(1)
      end
    end

    context 'when authenticated as agent' do
      it 'denies access to agent' do
        get "/api/v1/accounts/#{account.id}/reports/messages",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
