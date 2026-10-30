# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Roles API: Raqmi Connect', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:custom_role) do
    RaqmiConnect::CustomRole.create!(
      account: account,
      name: 'Support Tier 2',
      description: 'Handles escalations',
      permissions: %w[conversation_manage contact_manage]
    )
  end

  describe 'GET /api/v1/accounts/:account_id/custom_roles' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/custom_roles"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/custom_roles",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      it 'returns all custom roles for the account' do
        get "/api/v1/accounts/#{account.id}/custom_roles",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.length).to eq(1)
        expect(json.first['name']).to eq('Support Tier 2')
        expect(json.first['permissions']).to match_array(%w[conversation_manage contact_manage])
      end
    end
  end

  describe 'POST /api/v1/accounts/:account_id/custom_roles' do
    let(:params) do
      {
        custom_role: {
          name: 'New Custom Role',
          description: 'Custom description',
          permissions: ['conversation_participating_manage']
        }
      }
    end

    it 'creates a new custom role' do
      post "/api/v1/accounts/#{account.id}/custom_roles",
           params: params,
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['name']).to eq('New Custom Role')
      expect(json['permissions']).to eq(['conversation_participating_manage'])
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/custom_roles/:id' do
    it 'updates an existing custom role' do
      patch "/api/v1/accounts/#{account.id}/custom_roles/#{custom_role.id}",
            params: { custom_role: { name: 'Updated Name' } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(custom_role.reload.name).to eq('Updated Name')
    end

    it 'returns 404 for another account custom role' do
      other_account = create(:account)
      other_role = RaqmiConnect::CustomRole.create!(account: other_account, name: 'Other Role')

      patch "/api/v1/accounts/#{account.id}/custom_roles/#{other_role.id}",
            params: { custom_role: { name: 'Hacked' } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/custom_roles/:id' do
    it 'destroys the custom role' do
      delete "/api/v1/accounts/#{account.id}/custom_roles/#{custom_role.id}",
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:ok)
      expect { custom_role.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
