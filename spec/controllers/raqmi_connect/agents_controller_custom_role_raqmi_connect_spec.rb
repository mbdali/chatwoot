# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agents Controller Custom Role: Raqmi Connect', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:custom_role) do
    RaqmiConnect::CustomRole.create!(
      account: account,
      name: 'Tier 1 Agent',
      permissions: ['conversation_participating_manage']
    )
  end

  before do
    account.enable_features!('custom_roles')
  end

  describe 'POST /api/v1/accounts/:account_id/agents' do
    it 'assigns custom_role_id when creating an agent' do
      post "/api/v1/accounts/#{account.id}/agents",
           params: {
             agent: {
               name: 'New Custom Agent',
               email: 'newagent@example.com',
               role: 'agent'
             },
             custom_role_id: custom_role.id
           },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      created_user = User.find_by(email: 'newagent@example.com')
      expect(created_user.account_users.first.custom_role_id).to eq(custom_role.id)
    end

    it 'refuses assignment when feature flag is off' do
      account.disable_features!('custom_roles')

      post "/api/v1/accounts/#{account.id}/agents",
           params: {
             agent: {
               name: 'Blocked Agent',
               email: 'blocked@example.com',
               role: 'agent'
             },
             custom_role_id: custom_role.id
           },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/agents/:id' do
    it 'assigns custom_role_id on update' do
      patch "/api/v1/accounts/#{account.id}/agents/#{agent.id}",
            params: {
              agent: { name: 'Updated Agent' },
              custom_role_id: custom_role.id
            },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(agent.account_users.first.reload.custom_role_id).to eq(custom_role.id)
    end

    it 'clears custom_role_id when null is passed' do
      agent.account_users.first.update!(custom_role_id: custom_role.id)

      patch "/api/v1/accounts/#{account.id}/agents/#{agent.id}",
            params: {
              agent: { name: 'Updated Agent' },
              custom_role_id: nil
            },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(agent.account_users.first.reload.custom_role_id).to be_nil
    end

    it 'leaves custom_role_id untouched when key is omitted' do
      agent.account_users.first.update!(custom_role_id: custom_role.id)

      patch "/api/v1/accounts/#{account.id}/agents/#{agent.id}",
            params: {
              agent: { name: 'Updated Name Only' }
            },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(agent.account_users.first.reload.custom_role_id).to eq(custom_role.id)
    end

    it 'returns 404 when trying to assign another accounts custom role' do
      other_account = create(:account)
      other_role = RaqmiConnect::CustomRole.create!(account: other_account, name: 'Other Account Role')

      patch "/api/v1/accounts/#{account.id}/agents/#{agent.id}",
            params: {
              agent: { name: 'Attacker' },
              custom_role_id: other_role.id
            },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(agent.account_users.first.reload.custom_role_id).to be_nil
    end
  end
end
