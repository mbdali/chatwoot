# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::MessageReportsBuilder do
  let(:account) { create(:account) }
  let(:inbox1) { create(:inbox, account: account) }
  let(:inbox2) { create(:inbox, account: account) }
  let(:conversation1) { create(:conversation, account: account, inbox: inbox1) }
  let(:conversation2) { create(:conversation, account: account, inbox: inbox2) }

  before do
    # Current period messages:
    create(:message, account: account, inbox: inbox1, conversation: conversation1,
                     message_type: :incoming, created_at: 2.days.ago)
    create(:message, account: account, inbox: inbox2, conversation: conversation2,
                     message_type: :incoming, created_at: 3.days.ago)
    create(:message, account: account, inbox: inbox1, conversation: conversation1,
                     message_type: :outgoing, status: :delivered, created_at: 2.days.ago)
    create(:message, account: account, inbox: inbox1, conversation: conversation1,
                     message_type: :outgoing, status: :failed, created_at: 1.day.ago)

    # Previous period messages:
    create(:message, account: account, inbox: inbox1, conversation: conversation1,
                     message_type: :incoming, created_at: 10.days.ago)
    create(:message, account: account, inbox: inbox1, conversation: conversation1,
                     message_type: :outgoing, status: :delivered, created_at: 10.days.ago)
  end

  describe '#build' do
    let(:params) do
      {
        since: 7.days.ago.to_i.to_s,
        until: Time.current.to_i.to_s,
        group_by: 'day'
      }
    end

    it 'computes incoming message volume, trend, and stacked timeseries' do
      report = described_class.new(account, params).build

      incoming = report[:incoming]
      expect(incoming[:total]).to eq(2)
      expect(incoming[:previous_total]).to eq(1)
      expect(incoming[:trend]).to eq(100.0)
      expect(incoming[:chart_data][:series]).to be_present
      expect(incoming[:chart_data][:categories]).to be_present
    end

    it 'computes outgoing delivery rate, error rate, and status breakdown' do
      report = described_class.new(account, params).build

      outgoing = report[:outgoing]
      expect(outgoing[:total]).to eq(2)
      expect(outgoing[:delivered_count]).to eq(1)
      expect(outgoing[:failed_count]).to eq(1)
      expect(outgoing[:delivery_rate]).to eq(50.0)
      expect(outgoing[:error_rate]).to eq(50.0)
      expect(outgoing[:chart_data][:series]).to be_present
    end

    it 'filters metrics for a specific inbox' do
      inbox_params = params.merge(inbox_id: inbox1.id)
      report = described_class.new(account, inbox_params).build

      incoming = report[:incoming]
      expect(incoming[:total]).to eq(1)
      expect(incoming[:chart_data][:series].first[:id]).to eq("inbox_#{inbox1.id}")

      outgoing = report[:outgoing]
      expect(outgoing[:total]).to eq(2)
      series_ids = outgoing[:chart_data][:series].map { |s| s[:id] }
      expect(series_ids).to include('status_delivered', 'status_failed')
    end

    it 'groups outgoing by inbox when outgoing_group_by is inbox even with inbox_id' do
      inbox_params = params.merge(inbox_id: inbox1.id, outgoing_group_by: 'inbox')
      report = described_class.new(account, inbox_params).build

      outgoing = report[:outgoing]
      expect(outgoing[:chart_data][:series].first[:id]).to eq("inbox_#{inbox1.id}")
    end

    it 'groups outgoing timeseries by status when requested' do
      status_params = params.merge(outgoing_group_by: 'status')
      report = described_class.new(account, status_params).build

      outgoing = report[:outgoing]
      series_ids = outgoing[:chart_data][:series].map { |s| s[:id] }
      expect(series_ids).to include('status_delivered', 'status_failed', 'status_read', 'status_sent')
    end
  end
end
