# frozen_string_literal: true

# Raqmi Connect fork: grants report view access to custom-role agents with report_manage (docs/FORK.md).
module RaqmiConnect::ReportPolicyCustomRole
  def view?
    return true if account_user&.custom_role_permission?('report_manage')

    super
  end
end
