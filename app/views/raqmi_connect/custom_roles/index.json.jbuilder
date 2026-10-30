json.array! @custom_roles do |custom_role|
  json.partial! 'raqmi_connect/custom_roles/custom_role', custom_role: custom_role
end
