# frozen_string_literal: true

# Raqmi Connect fork: handles custom_role_id assignment on agent create and update (docs/FORK.md).
module RaqmiConnect::AgentsControllerCustomRole
  def create
    super
    assign_custom_role if @agent.present?
  end

  def update
    super
    assign_custom_role if @agent.present?
  end

  private

  def assign_custom_role
    return unless params.key?(:custom_role_id)

    if params[:custom_role_id].present?
      validate_custom_roles_feature_enabled!
      role = Current.account.custom_roles.find(params[:custom_role_id])
      @agent.current_account_user.update!(custom_role_id: role.id)
    else
      @agent.current_account_user.update!(custom_role_id: nil)
    end
  end

  def validate_custom_roles_feature_enabled!
    return if Current.account.feature_enabled?('custom_roles')

    raise Pundit::NotAuthorizedError
  end
end
