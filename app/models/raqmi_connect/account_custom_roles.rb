# frozen_string_literal: true

# Raqmi Connect fork: adds custom_roles association to Account (docs/FORK.md).
module RaqmiConnect::AccountCustomRoles
  extend ActiveSupport::Concern

  prepended do
    has_many :custom_roles, class_name: '::CustomRole', dependent: :destroy_async
  end
end
