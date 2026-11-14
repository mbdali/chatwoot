# frozen_string_literal: true

require 'down'

# Raqmi Connect fork: background job to download and store remote media from WhatsApp template messages.
# Ensures that messages sent with an external public URL have their files permanently stored in Chatwoot
# ActiveStorage, allowing agents to preview, view, and download what was sent.
class RaqmiConnect::WhatsappTemplateMediaDownloadJob < ApplicationJob
  queue_as :default

  MAX_DOWNLOAD_SIZE = 100.megabytes
  DOWNLOAD_TIMEOUT = 30

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return if attachment.blank? || attachment.file.attached?
    return if attachment.external_url.blank?

    downloaded_file = Down.download(
      attachment.external_url,
      max_size: MAX_DOWNLOAD_SIZE,
      read_timeout: DOWNLOAD_TIMEOUT,
      open_timeout: DOWNLOAD_TIMEOUT
    )

    filename = attachment.fallback_title.presence || downloaded_file.original_filename.presence || 'attachment'

    attachment.file.attach(
      io: downloaded_file,
      filename: filename,
      content_type: downloaded_file.content_type
    )

    attachment.message&.send_update_event
  rescue Down::Error, StandardError => e
    Rails.logger.warn("[RaqmiConnect] WhatsappTemplateMediaDownloadJob failed for attachment #{attachment_id} (#{attachment&.external_url}): #{e.message}")
  end
end
