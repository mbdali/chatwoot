# frozen_string_literal: true

# Raqmi Connect fork: filters conversation lists for custom-role agents (docs/FORK.md).
# Relies on upstream perform, user, account, and account_user.
module RaqmiConnect::PermissionFilterCustomRole
  def perform
    records = super
    return records unless account_user&.custom_role_agent?

    if account_user.custom_role_permission?('conversation_manage')
      records
    elsif account_user.custom_role_permission?('conversation_unassigned_manage')
      records.where(assignee_id: [nil, user.id])
    elsif account_user.custom_role_permission?('conversation_participating_manage')
      records.where(
        'conversations.assignee_id = :user_id OR EXISTS (
          SELECT 1 FROM conversation_participants
          WHERE conversation_participants.conversation_id = conversations.id
          AND conversation_participants.user_id = :user_id
        )',
        user_id: user.id
      )
    else
      records.none
    end
  end
end
