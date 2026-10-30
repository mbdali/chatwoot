# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Role Payloads: Raqmi Connect', type: :view do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:custom_role) do
    RaqmiConnect::CustomRole.create!(
      account: account,
      name: 'Custom Support Lead',
      description: 'Lead role description',
      permissions: %w[conversation_manage report_manage]
    )
  end

  describe 'api/v1/models/_agent.json.jbuilder' do
    it 'renders custom_role_id when custom_role is associated' do
      user.account_users.first.update!(custom_role_id: custom_role.id)
      Current.account = account

      render partial: 'api/v1/models/agent', formats: [:json], locals: { resource: user }
      json = JSON.parse(rendered)

      expect(json['custom_role_id']).to eq(custom_role.id)
    end
  end

  describe 'api/v1/models/_account_user.json.jbuilder' do
    it 'renders custom_role_id and custom_role details when role is present' do
      account_user = user.account_users.first
      account_user.update!(custom_role_id: custom_role.id)

      render partial: 'api/v1/models/account_user', formats: [:json], locals: { account_user: account_user }
      json = JSON.parse(rendered)

      expect(json['custom_role_id']).to eq(custom_role.id)
      expect(json['custom_role']).to eq(
        'id' => custom_role.id,
        'name' => 'Custom Support Lead',
        'description' => 'Lead role description',
        'permissions' => %w[conversation_manage report_manage]
      )
    end

    it 'renders null for custom_role when no role is assigned' do
      account_user = user.account_users.first

      render partial: 'api/v1/models/account_user', formats: [:json], locals: { account_user: account_user }
      json = JSON.parse(rendered)

      expect(json['custom_role_id']).to be_nil
      expect(json['custom_role']).to be_nil
    end
  end
end
