# frozen_string_literal: true

# Raqmi Connect fork: manages Help Center permissions for custom-role agents (docs/FORK.md).
# Prepended to PortalPolicy, ArticlePolicy, and CategoryPolicy.
module RaqmiConnect::HelpCenterPolicyCustomRole
  def index?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def show?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def create?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def update?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def edit?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def destroy?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def reorder?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def logo?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def send_instructions?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  def ssl_status?
    return custom_role_allowed? if account_user&.custom_role_agent?

    super
  end

  private

  def custom_role_allowed?
    account_user.custom_role_permission?('knowledge_base_manage')
  end
end
