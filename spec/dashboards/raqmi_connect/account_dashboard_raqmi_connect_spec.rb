# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaqmiConnect::AccountDashboard, type: :model do
  let(:account) { create(:account) }
  let(:dashboard) { AccountDashboard.new }

  describe 'dashboard attribute configuration' do
    it 'includes all_features and limits in attribute_types' do
      expect(dashboard.attribute_types[:all_features]).to eq(AccountFeaturesField)
      expect(dashboard.attribute_types[:limits]).to eq(AccountLimitsField)
    end

    it 'includes all_features, limits, and custom_attributes in show_page_attributes' do
      expect(dashboard.show_page_attributes).to include(:all_features, :limits, :custom_attributes)
    end

    it 'includes all_features and limits in form_attributes' do
      expect(dashboard.form_attributes).to include(:all_features, :limits)
      expect(dashboard.form_attributes('edit')).to include(:all_features, :limits)
    end
  end

  describe AccountFeaturesField do
    it 'returns data in to_s' do
      field = described_class.new(:all_features, { 'custom_roles' => true }, :show)
      expect(field.to_s).to eq({ 'custom_roles' => true })
    end
  end

  describe AccountLimitsField do
    it 'formats default and override limits into JSON' do
      field = described_class.new(:limits, { agents: 5 }, :show)
      parsed = JSON.parse(field.to_s)
      expect(parsed['agents']).to eq(5)
      expect(parsed).to have_key('inboxes')
    end
  end
end
