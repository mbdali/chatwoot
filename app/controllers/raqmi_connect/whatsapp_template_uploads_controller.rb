# frozen_string_literal: true

# Raqmi Connect fork: API controller for directly uploading media files for WhatsApp template headers.
# Stores the file in ActiveStorage, returns the public/download URL, filename, and blob signed_id.
class RaqmiConnect::WhatsappTemplateUploadsController < Api::V1::Accounts::BaseController
  MAX_FILE_SIZES = {
    'image' => 5.megabytes,
    'video' => 16.megabytes,
    'audio' => 16.megabytes,
    'document' => 100.megabytes
  }.freeze

  DEFAULT_MAX_FILE_SIZE = 100.megabytes

  def create
    file = params[:file]
    return render json: { error: 'File is required' }, status: :unprocessable_entity if file.blank?

    file_category = determine_file_category(file)
    return render json: { error: 'Unsupported file type' }, status: :unprocessable_entity if file_category.blank?

    max_size = MAX_FILE_SIZES.fetch(file_category, DEFAULT_MAX_FILE_SIZE)
    if file.size > max_size
      return render json: { error: "File exceeds the #{max_size / 1.megabyte}MB limit for #{file_category}s" },
                    status: :unprocessable_entity
    end

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type
    )

    ActiveStorage::Current.url_options = { host: ENV.fetch('FRONTEND_URL', 'http://localhost:3000') } if ActiveStorage::Current.url_options.blank?

    render json: {
      file_url: blob.url,
      file_name: file.original_filename,
      file_size: file.size,
      content_type: file.content_type,
      blob_id: blob.id,
      blob_signed_id: blob.signed_id
    }, status: :created
  end

  private

  def determine_file_category(file)
    content_type = file.content_type.to_s.downcase

    case content_type
    when %r{\Aimage/(jpeg|png|webp|gif)\z}
      'image'
    when %r{\Avideo/(mp4|3gpp|quicktime)\z}
      'video'
    when %r{\Aaudio/(aac|mp4|mpeg|amr|ogg|opus)\z}
      'audio'
    when %r{\Aapplication/(pdf|msword|vnd\.openxmlformats|vnd\.ms-|zip|rtf|json)|text/(plain|csv)\z}
      'document'
    else
      # Fallback by extension if mime type is generic octet-stream
      filename = file.original_filename.to_s.downcase
      if filename.match?(/\.(jpg|jpeg|png|webp)$/)
        'image'
      elsif filename.match?(/\.(mp4|3gp|mov)$/)
        'video'
      elsif filename.match?(/\.(pdf|doc|docx|xls|xlsx|csv|txt|rtf)$/)
        'document'
      end
    end
  end
end
