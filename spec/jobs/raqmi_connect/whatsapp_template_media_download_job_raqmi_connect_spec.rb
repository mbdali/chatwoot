# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappTemplateMediaDownloadJob do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation, account: account) }
  let(:attachment) do
    message.attachments.create!(
      account_id: account.id,
      file_type: :file,
      external_url: 'https://example.com/invoice.pdf',
      fallback_title: 'invoice.pdf'
    )
  end

  describe '#perform' do
    it 'downloads remote file and attaches it to attachment.file, then fires send_update_event' do
      stub_request(:get, 'https://example.com/invoice.pdf').to_return(
        status: 200,
        body: File.read('spec/assets/sample.pdf'),
        headers: { 'Content-Type' => 'application/pdf' }
      )

      allow(Attachment).to receive(:find_by).with(id: attachment.id).and_return(attachment)
      expect(attachment.message).to receive(:send_update_event)

      described_class.new.perform(attachment.id)

      expect(attachment.reload.file.attached?).to be true
      expect(attachment.file.filename.to_s).to eq('invoice.pdf')
    end

    it 'skips download if file is already attached' do
      attachment.file.attach(
        io: StringIO.new('data'),
        filename: 'already.pdf',
        content_type: 'application/pdf'
      )

      described_class.new.perform(attachment.id)

      expect(WebMock).not_to have_requested(:get, 'https://example.com/invoice.pdf')
    end

    it 'logs and handles Down::Error gracefully without re-raising' do
      stub_request(:get, 'https://example.com/invoice.pdf').to_return(status: 404)

      expect { described_class.new.perform(attachment.id) }.not_to raise_error
      expect(attachment.reload.file.attached?).to be false
    end
  end
end
