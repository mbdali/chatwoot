# frozen_string_literal: true

# Raqmi Connect fork rake tasks (docs/FORK.md).
namespace :raqmi_connect do
  desc 'Enable custom_roles feature flag for an account (or all accounts if omitted)'
  task :enable_custom_roles, [:account_id] => :environment do |_t, args|
    if args[:account_id].present?
      account = Account.find(args[:account_id])
      account.enable_features!('custom_roles')
      puts "Enabled custom_roles for Account ##{account.id} (#{account.name})"
    else
      Account.find_each do |account|
        account.enable_features!('custom_roles')
      end
      puts "Enabled custom_roles for all accounts (#{Account.count} accounts)"
    end
  end
end
