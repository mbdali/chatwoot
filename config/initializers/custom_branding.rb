# frozen_string_literal: true

# Synchronize custom branding environment variables with InstallationConfig table
Rails.application.config.after_initialize do
  branding_mappings = {
    'INSTALLATION_NAME' => ENV.fetch('INSTALLATION_NAME', nil),
    'BRAND_NAME' => ENV.fetch('BRAND_NAME', nil),
    'BRAND_URL' => ENV.fetch('BRAND_URL', nil),
    'WIDGET_BRAND_URL' => ENV.fetch('WIDGET_BRAND_URL', nil),
    'TERMS_URL' => ENV.fetch('TERMS_URL', nil),
    'PRIVACY_URL' => ENV.fetch('PRIVACY_URL', nil),
    'LOGO' => ENV.fetch('LOGO', nil) || ENV.fetch('LOGO_URL', nil),
    'LOGO_DARK' => ENV.fetch('LOGO_DARK', nil),
    'LOGO_THUMBNAIL' => ENV.fetch('LOGO_THUMBNAIL', nil) || ENV.fetch('LOGO_THUMBNAIL_URL', nil)
  }.compact

  if branding_mappings.any? && ActiveRecord::Base.connection.table_exists?('installation_configs')
    updated = false
    branding_mappings.each do |key, value|
      config = InstallationConfig.find_or_initialize_by(name: key)
      if config.value != value
        config.value = value
        config.locked = false if config.respond_to?(:locked)
        config.save!
        updated = true
      end
    end
    GlobalConfig.clear_cache if updated && defined?(GlobalConfig)
  end
rescue StandardError => e
  Rails.logger.warn "[CustomBranding] Synchronization skipped: #{e.message}"
end
