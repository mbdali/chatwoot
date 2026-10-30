# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Roles License Isolation: Raqmi Connect' do
  it 'does not prepend fork modules to AccountUser when enterprise/ directory exists' do
    if Rails.root.join('enterprise').exist?
      expect(AccountUser.ancestors).not_to include(RaqmiConnect::AccountUserCustomRole)
    else
      expect(AccountUser.ancestors).to include(RaqmiConnect::AccountUserCustomRole)
    end
  end

  it 'raises at boot if enterprise/ exists and DISABLE_ENTERPRISE is true' do
    skip 'Only applicable when enterprise/ directory exists' unless Rails.root.join('enterprise').exist?

    expect do
      with_modified_env DISABLE_ENTERPRISE: 'true' do
        if Rails.root.join('enterprise').exist? && ActiveModel::Type::Boolean.new.cast(ENV.fetch('DISABLE_ENTERPRISE', false))
          raise 'DISABLE_ENTERPRISE still loads enterprise/ code; build without the enterprise/ directory instead'
        end
      end
    end.to raise_error(RuntimeError, /DISABLE_ENTERPRISE still loads enterprise\/ code/)
  end
end
