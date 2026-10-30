# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaqmiConnect::CustomRole, type: :model do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }

  describe 'validations' do
    it 'validates presence of name' do
      role = described_class.new(account: account, name: nil)
      expect(role).not_to be_valid
      expect(role.errors[:name]).to include("can't be blank")
    end

    it 'validates uniqueness of name scoped to account' do
      described_class.create!(account: account, name: 'Support Lead', permissions: ['conversation_manage'])
      duplicate = described_class.new(account: account, name: 'Support Lead', permissions: ['contact_manage'])
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')

      other_account = create(:account)
      other_role = described_class.new(account: other_account, name: 'Support Lead', permissions: ['contact_manage'])
      expect(other_role).to be_valid
    end

    it 'rejects unknown permissions' do
      role = described_class.new(account: account, name: 'Invalid Role', permissions: %w[conversation_manage unknown_perm])
      expect(role).not_to be_valid
      expect(role.errors[:permissions]).to include('contains invalid permissions: unknown_perm')
    end

    it 'accepts valid permissions' do
      role = described_class.new(
        account: account,
        name: 'Full Support Role',
        permissions: described_class::PERMISSIONS
      )
      expect(role).to be_valid
    end
  end

  describe 'associations and callbacks' do
    it 'nullifies account_user custom_role_id on destroy' do
      role = described_class.create!(account: account, name: 'Tier 1', permissions: ['conversation_participating_manage'])
      account_user = user.account_users.first
      account_user.update!(custom_role_id: role.id)

      expect { role.destroy! }.to change { account_user.reload.custom_role_id }.from(role.id).to(nil)
    end

    it 'invalidates unread count cache and dispatches event when permissions change' do
      role = described_class.create!(account: account, name: 'Tier 1', permissions: ['conversation_participating_manage'])
      user.account_users.first.update!(custom_role_id: role.id)

      expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
        ACCOUNT_CACHE_INVALIDATED,
        anything,
        account: account,
        cache_keys: account.cache_keys
      )

      role.update!(permissions: %w[conversation_participating_manage report_manage])
    end

    it 'invalidates unread count cache and dispatches event on destroy' do
      role = described_class.create!(account: account, name: 'Tier 1', permissions: ['conversation_participating_manage'])
      user.account_users.first.update!(custom_role_id: role.id)

      expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
        ACCOUNT_CACHE_INVALIDATED,
        anything,
        account: account,
        cache_keys: account.cache_keys
      )

      role.destroy!
    end
  end
end
