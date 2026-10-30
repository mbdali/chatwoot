# frozen_string_literal: true

# Raqmi Connect fork: MIT-compliant custom role policy (docs/FORK.md).
# Bound to top-level ::CustomRolePolicy when enterprise/ is absent.
class RaqmiConnect::CustomRolePolicy < ApplicationPolicy
  def index?
    account_user.administrator?
  end

  def show?
    account_user.administrator?
  end

  def create?
    account_user.administrator?
  end

  def update?
    account_user.administrator?
  end

  def destroy?
    account_user.administrator?
  end
end
