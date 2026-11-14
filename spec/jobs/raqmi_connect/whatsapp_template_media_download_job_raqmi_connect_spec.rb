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
      temp_file = Tempfile.new(['invoice', '.pdf'])
      temp_file.write('%PDF-1.4 test')
      temp_file.rewind

      # Down::ChunkedIO / tempfile mock
      allow(temp_file).to receive(:content_type).and_return('application/pdf')
      allow(temp_file).to receive(:original_filename).and_return('invoice.pdf')
      allow(Down).to receive(:download).with(
        'https://example.com/invoice.pdf',
        max_size: 100.megabytes,
        read_timeout: 30,
        open_timeout: 30
      ).and_return(temp_file)

      expect(message).to receive(:send_update_event)

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

      expect(Down).not_to receive(:download)
      described_class.new.perform(attachment.id)
    end

    it 'logs and handles Down::Error gracefully without re-raising' do
      allow(Down).to receive(:download).and_raise(Down::NotFound.new('404 Not Found'))

      expect { described_class.new.perform(attachment.id) }.not_to raise_error
      expect(attachment.reload.file.attached?).to be false
    end
  end
end
