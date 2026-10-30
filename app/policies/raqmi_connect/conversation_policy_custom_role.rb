# frozen_string_literal: true

# Raqmi Connect fork: gates conversation access for custom-role agents (docs/FORK.md).
# Relies on upstream agent_can_view_conversation?, assigned_to_user?, and participant?.
module RaqmiConnect::ConversationPolicyCustomRole
  def show?
    return super unless account_user&.custom_role_agent?
    return false unless agent_can_view_conversation?

    if account_user.custom_role_permission?('conversation_manage')
      true
    elsif account_user.custom_role_permission?('conversation_unassigned_manage')
      record.assignee_id.nil? || assigned_to_user?
    elsif account_user.custom_role_permission?('conversation_participating_manage')
      assigned_to_user? || participant?
    else
      false
    end
  end
end
