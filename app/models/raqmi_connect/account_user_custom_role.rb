# frozen_string_literal: true

# Raqmi Connect fork: adds custom_role association and permission helpers to AccountUser (docs/FORK.md).
module RaqmiConnect::AccountUserCustomRole
  extend ActiveSupport::Concern

  prepended do
    belongs_to :custom_role, class_name: 'CustomRole', optional: true
  end

  def permissions
    return super unless agent? && custom_role.present?

    custom_role.permissions + ['custom_role']
  end

  def custom_role_agent?
    agent? && custom_role_id.present?
  end

  def custom_role_permission?(permission_name)
    custom_role_agent? && custom_role&.permissions&.include?(permission_name.to_s)
  end
end
