# frozen_string_literal: true

# Raqmi Connect fork: restricts contact access for custom-role agents without contact_manage (docs/FORK.md).
module RaqmiConnect::ContactPolicyCustomRole
  def index?
    return false if denied_custom_role?

    super
  end

  def active?
    return false if denied_custom_role?

    super
  end

  def search?
    return false if denied_custom_role?

    super
  end

  def filter?
    return false if denied_custom_role?

    super
  end

  def show?
    return false if denied_custom_role?

    super
  end

  def create?
    return false if denied_custom_role?

    super
  end

  def update?
    return false if denied_custom_role?

    super
  end

  def avatar?
    return false if denied_custom_role?

    super
  end

  def contactable_inboxes?
    return false if denied_custom_role?

    super
  end

  def destroy_custom_attributes?
    return false if denied_custom_role?

    super
  end

  private

  def denied_custom_role?
    account_user&.custom_role_agent? && !account_user.custom_role_permission?('contact_manage')
  end
end
