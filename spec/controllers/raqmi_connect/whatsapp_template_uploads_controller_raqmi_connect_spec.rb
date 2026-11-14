# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappTemplateUploadsController, type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'POST /api/v1/accounts/:account_id/whatsapp_templates/upload_media' do
    context 'when authenticated as account agent' do
      it 'uploads an image file and returns blob URL and signed id' do
        file = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')

        post "/api/v1/accounts/#{account.id}/whatsapp_templates/upload_media",
             params: { file: file },
             headers: agent.create_new_auth_token

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['file_url']).to be_present
        expect(json['file_name']).to eq('avatar.png')
        expect(json['content_type']).to eq('image/png')
        expect(json['blob_signed_id']).to be_present
      end

      it 'uploads a document file and returns blob URL and signed id' do
        file = Rack::Test::UploadedFile.new(
          StringIO.new('%PDF-1.4 test content'),
          'application/pdf',
          original_filename: 'invoice.pdf'
        )

        post "/api/v1/accounts/#{account.id}/whatsapp_templates/upload_media",
             params: { file: file },
             headers: agent.create_new_auth_token

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['file_url']).to be_present
        expect(json['file_name']).to eq('invoice.pdf')
        expect(json['content_type']).to eq('application/pdf')
        expect(json['blob_signed_id']).to be_present
      end

      it 'returns 422 if file param is missing' do
        post "/api/v1/accounts/#{account.id}/whatsapp_templates/upload_media",
             params: {},
             headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('File is required')
      end

      it 'returns 422 if file type is unsupported' do
        file = Rack::Test::UploadedFile.new(
          StringIO.new('binary data'),
          'application/x-dosexec',
          original_filename: 'program.exe'
        )

        post "/api/v1/accounts/#{account.id}/whatsapp_templates/upload_media",
             params: { file: file },
             headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Unsupported file type')
      end

      it 'returns 422 if image file exceeds max size limit' do
        file = Rack::Test::UploadedFile.new(
          StringIO.new('x' * (6.megabytes)),
          'image/png',
          original_filename: 'large.png'
        )

        post "/api/v1/accounts/#{account.id}/whatsapp_templates/upload_media",
             params: { file: file },
             headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to match(/File exceeds the 5MB limit/i)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        file = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')

        post "/api/v1/accounts/#{account.id}/whatsapp_templates/upload_media",
             params: { file: file }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
