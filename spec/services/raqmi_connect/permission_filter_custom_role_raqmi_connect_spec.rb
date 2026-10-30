# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaqmiConnect::PermissionFilterCustomRole do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }

  let(:test_service_class) do
    Class.new(Conversations::PermissionFilterService) do
      prepend RaqmiConnect::PermissionFilterCustomRole
    end
  end

  let!(:unassigned_conv) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let!(:assigned_to_me) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:assigned_to_other) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }
  let!(:participating_conv) do
    conv = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
    conv.conversation_participants.create!(user: agent)
    conv
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: other_agent)
  end

  def filter_conversations(user)
    test_service_class.new(account.conversations, user, account).perform
  end

  context 'with conversation_manage permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Lead', permissions: ['conversation_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'returns all conversations in accessible inboxes' do
      expect(filter_conversations(agent)).to match_array([unassigned_conv, assigned_to_me, assigned_to_other, participating_conv])
    end
  end

  context 'with conversation_unassigned_manage permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Unassigned', permissions: ['conversation_unassigned_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'returns unassigned and assigned to me conversations' do
      expect(filter_conversations(agent)).to match_array([unassigned_conv, assigned_to_me])
    end
  end

  context 'with conversation_participating_manage permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Participant', permissions: ['conversation_participating_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'returns assigned to me and participating conversations' do
      expect(filter_conversations(agent)).to match_array([assigned_to_me, participating_conv])
    end
  end

  context 'without conversation permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'NoConv', permissions: ['contact_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'returns none' do
      expect(filter_conversations(agent)).to be_empty
    end
  end
end
