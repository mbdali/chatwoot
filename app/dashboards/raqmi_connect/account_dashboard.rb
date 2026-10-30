# frozen_string_literal: true

module RaqmiConnect
  module AccountDashboard
    def attribute_types
      super.merge(
        limits: AccountLimitsField,
        all_features: AccountFeaturesField
      )
    end

    def show_page_attributes
      (super + %i[custom_attributes limits all_features]).uniq
    end

    def form_attributes(action = nil)
      (super(action) + %i[limits all_features]).uniq
    end

    def permitted_attributes(action = nil)
      attrs = super(action)
      attrs << { limits: {} } unless attrs.any? { |a| a.is_a?(Hash) && a.key?(:limits) }
      attrs
    end
  end
end
