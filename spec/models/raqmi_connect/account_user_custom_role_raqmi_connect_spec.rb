# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaqmiConnect::AccountUserCustomRole, type: :model do
  let(:account) { create(:account) }
  let(:custom_role) do
    RaqmiConnect::CustomRole.create!(
      account: account,
      name: 'Agent Lead',
      permissions: %w[conversation_manage report_manage]
    )
  end

  # Test dummy class including the concern if enterprise/ is present in the workspace
  let(:test_class) do
    Class.new(AccountUser) do
      prepend RaqmiConnect::AccountUserCustomRole

      def self.name
        'TestAccountUser'
      end
    end
  end

  let(:agent_account_user) do
    user = create(:user, account: account, role: :agent)
    test_class.find(user.account_users.first.id)
  end

  let(:admin_account_user) do
    user = create(:user, account: account, role: :administrator)
    test_class.find(user.account_users.first.id)
  end

  describe '#permissions' do
    it 'returns custom role permissions plus custom_role tag for custom-role agent' do
      agent_account_user.update!(custom_role_id: custom_role.id)
      expect(agent_account_user.permissions).to match_array(%w[conversation_manage report_manage custom_role])
    end

    it 'returns agent permission for plain agent without custom role' do
      expect(agent_account_user.permissions).to eq(['agent'])
    end

    it 'keeps administrator permission even if custom_role_id is present' do
      admin_account_user.update_column(:custom_role_id, custom_role.id)
      expect(admin_account_user.permissions).to eq(['administrator'])
    end
  end

  describe '#custom_role_agent?' do
    it 'returns true only when agent has custom_role_id' do
      expect(agent_account_user.custom_role_agent?).to be false
      agent_account_user.update!(custom_role_id: custom_role.id)
      expect(agent_account_user.custom_role_agent?).to be true
      expect(admin_account_user.custom_role_agent?).to be false
    end
  end

  describe '#custom_role_permission?' do
    it 'checks whether the assigned role has the permission' do
      agent_account_user.update!(custom_role_id: custom_role.id)
      expect(agent_account_user.custom_role_permission?('conversation_manage')).to be true
      expect(agent_account_user.custom_role_permission?('contact_manage')).to be false
    end
  end
end
