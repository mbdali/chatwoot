# frozen_string_literal: true

# Raqmi Connect fork: prepended to Messages::MessageBuilder to attach template media to the message.
# For direct uploads (blob_signed_id), it adds the blob to attachments so it is attached directly.
# For public URLs (media_url), it creates an attachment with external_url and enqueues a background
# job to download and persist the media into ActiveStorage.
module RaqmiConnect::WhatsappTemplateAttachmentBuilder
  def perform
    prepare_template_media_attachment
    super.tap do |msg|
      finalize_template_external_media(msg) if msg.persisted?
    end
  end

  private

  def prepare_template_media_attachment
    header_params = extract_template_header_params
    return if header_params.blank?

    blob_signed_id = header_params[:blob_signed_id] || header_params['blob_signed_id']
    media_url = header_params[:media_url] || header_params['media_url']

    if blob_signed_id.present?
      @attachments = Array(@attachments) + [blob_signed_id]
    elsif media_url.present?
      @pending_template_external_media = header_params
    end
  end

  def finalize_template_external_media(message)
    return if @pending_template_external_media.blank?

    header = @pending_template_external_media
    media_url = header[:media_url] || header['media_url']
    media_type = header[:media_type] || header['media_type']
    media_name = header[:media_name] || header['media_name']

    clean_fallback = media_name.presence
    if clean_fallback.blank?
      begin
        clean_fallback = File.basename(URI.parse(media_url).path)
      rescue StandardError
        clean_fallback = 'attachment'
      end
    end

    attachment = message.attachments.create!(
      account_id: message.account_id,
      file_type: map_media_type_to_attachment_type(media_type),
      external_url: media_url,
      fallback_title: clean_fallback
    )

    RaqmiConnect::WhatsappTemplateMediaDownloadJob.perform_later(attachment.id)
  rescue StandardError => e
    Rails.logger.warn("[RaqmiConnect] Failed to attach/enqueue template media: #{e.message}")
  end

  def extract_template_header_params
    return nil if @params.blank?

    template_params_raw = @params[:template_params]
    return nil if template_params_raw.blank?

    parsed = if template_params_raw.is_a?(String)
               begin
                 JSON.parse(template_params_raw)
               rescue StandardError
                 {}
               end
             else
               template_params_raw
             end

    parsed.dig(:processed_params, :header) || parsed.dig('processed_params', 'header')
  end

  def map_media_type_to_attachment_type(media_type)
    case media_type.to_s.downcase
    when 'image'
      :image
    when 'video'
      :video
    when 'audio'
      :audio
    else
      :file
    end
  end
end
