# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaqmiConnect::ConversationPolicyCustomRole do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  let(:test_policy_class) do
    Class.new(ConversationPolicy) do
      prepend RaqmiConnect::ConversationPolicyCustomRole
    end
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: other_agent)
  end

  def policy_for(user, record)
    account_user = user.account_users.first
    test_policy_class.new({ user: user, account: account, account_user: account_user }, record)
  end

  context 'with conversation_manage permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Lead', permissions: ['conversation_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'allows viewing any conversation in accessible inbox' do
      conversation.update!(assignee: other_agent)
      expect(policy_for(agent, conversation).show?).to be true
    end

    it 'denies viewing conversation without inbox or team access' do
      other_inbox = create(:inbox, account: account)
      inaccessible_conversation = create(:conversation, account: account, inbox: other_inbox)
      expect(policy_for(agent, inaccessible_conversation).show?).to be false
    end
  end

  context 'with conversation_unassigned_manage permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Unassigned', permissions: ['conversation_unassigned_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'allows viewing unassigned conversations' do
      conversation.update!(assignee: nil)
      expect(policy_for(agent, conversation).show?).to be true
    end

    it 'allows viewing conversations assigned to self' do
      conversation.update!(assignee: agent)
      expect(policy_for(agent, conversation).show?).to be true
    end

    it 'denies viewing conversations assigned to another agent' do
      conversation.update!(assignee: other_agent)
      expect(policy_for(agent, conversation).show?).to be false
    end
  end

  context 'with conversation_participating_manage permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Participant', permissions: ['conversation_participating_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'allows viewing conversations assigned to self' do
      conversation.update!(assignee: agent)
      expect(policy_for(agent, conversation).show?).to be true
    end

    it 'allows viewing conversations where user is a participant' do
      conversation.update!(assignee: other_agent)
      conversation.conversation_participants.create!(user: agent)
      expect(policy_for(agent, conversation).show?).to be true
    end

    it 'denies viewing conversations without assignment or participation' do
      conversation.update!(assignee: other_agent)
      expect(policy_for(agent, conversation).show?).to be false
    end
  end

  context 'without any conversation permission' do
    let(:role) { RaqmiConnect::CustomRole.create!(account: account, name: 'Restricted', permissions: ['contact_manage']) }

    before { agent.account_users.first.update!(custom_role_id: role.id) }

    it 'denies viewing conversations' do
      conversation.update!(assignee: agent)
      expect(policy_for(agent, conversation).show?).to be false
    end
  end

  context 'with plain agent or administrator' do
    it 'allows plain agent to view conversation in their inbox' do
      expect(policy_for(agent, conversation).show?).to be true
    end

    it 'allows administrator to view any conversation' do
      admin = create(:user, account: account, role: :administrator)
      expect(policy_for(admin, conversation).show?).to be true
    end
  end
end
