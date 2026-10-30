# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Role Policy Prepends: Raqmi Connect' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:account_user) { agent.account_users.first }
  let(:contact) { create(:contact, account: account) }

  describe RaqmiConnect::ContactPolicyCustomRole do
    let(:policy_class) do
      Class.new(ContactPolicy) do
        prepend RaqmiConnect::ContactPolicyCustomRole
      end
    end

    def policy(user)
      policy_class.new({ user: user, account: account, account_user: user.account_users.first }, contact)
    end

    context 'with contact_manage permission' do
      let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Contact Manager', permissions: ['contact_manage']) }

      before { account_user.update!(custom_role_id: role.id) }

      it 'allows viewing and updating contacts' do
        expect(policy(agent).index?).to be true
        expect(policy(agent).show?).to be true
        expect(policy(agent).create?).to be true
        expect(policy(agent).update?).to be true
      end

      it 'keeps import and export administrator-only' do
        expect(policy(agent).import?).to be false
        expect(policy(agent).export?).to be false
        expect(policy(admin).import?).to be true
        expect(policy(admin).export?).to be true
      end
    end

    context 'without contact_manage permission' do
      let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Chat Only', permissions: ['conversation_manage']) }

      before { account_user.update!(custom_role_id: role.id) }

      it 'denies viewing and modifying contacts' do
        expect(policy(agent).index?).to be false
        expect(policy(agent).show?).to be false
        expect(policy(agent).create?).to be false
        expect(policy(agent).update?).to be false
        expect(policy(agent).search?).to be false
        expect(policy(agent).filter?).to be false
      end
    end
  end

  describe RaqmiConnect::ReportPolicyCustomRole do
    let(:policy_class) do
      Class.new(ReportPolicy) do
        prepend RaqmiConnect::ReportPolicyCustomRole
      end
    end

    def policy(user)
      policy_class.new({ user: user, account: account, account_user: user.account_users.first }, nil)
    end

    it 'allows view? with report_manage permission' do
      role = RaqmiConnect::CustomRole.create!(account: account, name: 'Analyst', permissions: ['report_manage'])
      account_user.update!(custom_role_id: role.id)
      expect(policy(agent).view?).to be true
    end

    it 'denies view? without report_manage permission for custom-role agent' do
      role = RaqmiConnect::CustomRole.create!(account: account, name: 'Restricted', permissions: ['conversation_manage'])
      account_user.update!(custom_role_id: role.id)
      expect(policy(agent).view?).to be false
    end
  end

  describe RaqmiConnect::CsatSurveyResponsePolicyCustomRole do
    let(:policy_class) do
      Class.new(CsatSurveyResponsePolicy) do
        prepend RaqmiConnect::CsatSurveyResponsePolicyCustomRole
      end
    end

    def policy(user)
      policy_class.new({ user: user, account: account, account_user: user.account_users.first }, nil)
    end

    it 'allows metrics? and download? with report_manage permission' do
      role = RaqmiConnect::CustomRole.create!(account: account, name: 'Analyst', permissions: ['report_manage'])
      account_user.update!(custom_role_id: role.id)
      expect(policy(agent).index?).to be true
      expect(policy(agent).metrics?).to be true
      expect(policy(agent).download?).to be true
    end

    it 'denies metrics? and download? without report_manage' do
      role = RaqmiConnect::CustomRole.create!(account: account, name: 'Restricted', permissions: ['conversation_manage'])
      account_user.update!(custom_role_id: role.id)
      expect(policy(agent).index?).to be false
      expect(policy(agent).metrics?).to be false
      expect(policy(agent).download?).to be false
    end
  end

  describe RaqmiConnect::HelpCenterPolicyCustomRole do
    let(:portal) { create(:portal, account: account) }
    let(:policy_class) do
      Class.new(PortalPolicy) do
        prepend RaqmiConnect::HelpCenterPolicyCustomRole
      end
    end

    def policy(user)
      policy_class.new({ user: user, account: account, account_user: user.account_users.first }, portal)
    end

    it 'allows help center actions with knowledge_base_manage' do
      role = RaqmiConnect::CustomRole.create!(account: account, name: 'Author', permissions: ['knowledge_base_manage'])
      account_user.update!(custom_role_id: role.id)
      expect(policy(agent).index?).to be true
      expect(policy(agent).show?).to be true
      expect(policy(agent).create?).to be true
      expect(policy(agent).update?).to be true
      expect(policy(agent).destroy?).to be true
    end

    it 'denies all help center actions without knowledge_base_manage for custom-role agent' do
      role = RaqmiConnect::CustomRole.create!(account: account, name: 'Chat Only', permissions: ['conversation_manage'])
      account_user.update!(custom_role_id: role.id)
      expect(policy(agent).index?).to be false
      expect(policy(agent).show?).to be false
      expect(policy(agent).create?).to be false
      expect(policy(agent).update?).to be false
      expect(policy(agent).destroy?).to be false
    end
  end
end
