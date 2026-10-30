# frozen_string_literal: true

# Raqmi Connect fork: OSS partial for custom role info on account_user (docs/FORK.md).
# Emits custom_role_id and custom_role object (or null) to match frontend expectations.
custom_role = account_user.custom_role

json.custom_role_id account_user.custom_role_id
if custom_role
  json.custom_role do
    json.extract! custom_role, :id, :name, :description, :permissions
  end
else
  json.custom_role nil
end
