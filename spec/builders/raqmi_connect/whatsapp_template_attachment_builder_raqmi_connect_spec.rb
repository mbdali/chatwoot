# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappTemplateAttachmentBuilder do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '#perform' do
    context 'when template_params has blob_signed_id (direct upload)' do
      let(:blob) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new('image data'), filename: 'test.png', content_type: 'image/png') }
      let(:params) do
        ActionController::Parameters.new({
          content: 'Hello {{1}}',
          template_params: {
            name: 'sample_template',
            processed_params: {
              header: {
                media_type: 'image',
                media_url: 'https://example.com/blob_url.png',
                blob_signed_id: blob.signed_id
              },
              body: { '1': 'John' }
            }
          }
        })
      end

      it 'attaches the blob as an attachment to the message' do
        builder = Messages::MessageBuilder.new(user, conversation, params)
        message = builder.perform

        expect(message.attachments.count).to eq(1)
        attachment = message.attachments.first
        expect(attachment.file.attached?).to be true
        expect(attachment.file.filename.to_s).to eq('test.png')
        expect(attachment.file_type).to eq('image')
      end
    end

    context 'when template_params has public media_url without blob_signed_id (URL mode)' do
      let(:params) do
        ActionController::Parameters.new({
          content: 'Hello {{1}}',
          template_params: {
            name: 'doc_template',
            processed_params: {
              header: {
                media_type: 'document',
                media_url: 'https://example.com/files/invoice.pdf',
                media_name: 'Invoice_101.pdf'
              },
              body: { '1': 'John' }
            }
          }
        })
      end

      it 'creates an attachment with external_url and enqueues download job' do
        expect do
          builder = Messages::MessageBuilder.new(user, conversation, params)
          message = builder.perform

          expect(message.attachments.count).to eq(1)
          attachment = message.attachments.first
          expect(attachment.external_url).to eq('https://example.com/files/invoice.pdf')
          expect(attachment.fallback_title).to eq('Invoice_101.pdf')
          expect(attachment.file_type).to eq('file')
        end.to have_enqueued_job(RaqmiConnect::WhatsappTemplateMediaDownloadJob)
      end
    end

    context 'when template_params is absent or has no media header' do
      let(:params) do
        ActionController::Parameters.new({
          content: 'Regular text message'
        })
      end

      it 'builds standard message without attachments' do
        builder = Messages::MessageBuilder.new(user, conversation, params)
        message = builder.perform

        expect(message.attachments.count).to eq(0)
      end
    end
  end
end
