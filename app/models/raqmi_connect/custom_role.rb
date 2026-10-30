# frozen_string_literal: true

# Raqmi Connect fork: MIT-compliant custom role model (docs/FORK.md).
# Bound to top-level ::CustomRole when enterprise/ is absent.
class RaqmiConnect::CustomRole < ApplicationRecord
  self.table_name = 'custom_roles'

  belongs_to :account
  has_many :account_users, class_name: 'AccountUser', foreign_key: 'custom_role_id', inverse_of: :custom_role, dependent: :nullify

  PERMISSIONS = %w[
    conversation_manage
    conversation_unassigned_manage
    conversation_participating_manage
    contact_manage
    report_manage
    knowledge_base_manage
  ].freeze

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validate :validate_permissions

  before_destroy :collect_affected_user_ids
  after_save :invalidate_cache_on_permissions_change
  after_destroy :invalidate_cache_after_destroy

  private

  def validate_permissions
    return if permissions.blank?

    unknown = permissions - PERMISSIONS
    errors.add(:permissions, "contains invalid permissions: #{unknown.join(', ')}") if unknown.any?
  end

  def collect_affected_user_ids
    @affected_user_ids = account_users.pluck(:user_id)
  end

  def invalidate_cache_on_permissions_change
    return unless saved_change_to_permissions?

    invalidate_unread_counts(account_users.pluck(:user_id))
    dispatch_account_cache_invalidated
  end

  def invalidate_cache_after_destroy
    invalidate_unread_counts(@affected_user_ids)
    dispatch_account_cache_invalidated
  end

  def invalidate_unread_counts(user_ids)
    return if user_ids.blank?

    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).users_visibility_changed!(user_ids: user_ids)
  end

  def dispatch_account_cache_invalidated
    Rails.configuration.dispatcher.dispatch(
      ACCOUNT_CACHE_INVALIDATED,
      Time.zone.now,
      account: account,
      cache_keys: account.cache_keys
    )
  end
end
