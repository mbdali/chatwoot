# frozen_string_literal: true

# Raqmi Connect fork: grants CSAT survey response access to custom-role agents with report_manage (docs/FORK.md).
module RaqmiConnect::CsatSurveyResponsePolicyCustomRole
  def index?
    return true if account_user&.custom_role_permission?('report_manage')

    super
  end

  def metrics?
    return true if account_user&.custom_role_permission?('report_manage')

    super
  end

  def download?
    return true if account_user&.custom_role_permission?('report_manage')

    super
  end
end
