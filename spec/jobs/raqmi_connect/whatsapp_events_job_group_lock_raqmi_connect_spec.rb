# frozen_string_literal: true

# Raqmi Connect fork spec (docs/FORK.md). Kept out of upstream's spec files so a merge cannot conflict.
require 'rails_helper'

describe RaqmiConnect::WhatsappEventsJobGroupLock do
  let(:job) { Webhooks::WhatsappEventsJob.new }

  it 'returns group_id as contact_sender_id when payload is a group message' do
    payload = {
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            messages: [{
              from: '15551234567',
              group_id: '120363012345678901@g.us',
              type: 'text'
            }]
          }
        }]
      }]
    }.with_indifferent_access

    expect(job.send(:contact_sender_id, payload)).to eq('120363012345678901@g.us')
  end

  it 'falls back to upstream sender id when payload is an individual message' do
    payload = {
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            messages: [{
              from: '15551234567',
              type: 'text'
            }]
          }
        }]
      }]
    }.with_indifferent_access

    expect(job.send(:contact_sender_id, payload)).to eq('15551234567')
  end
end
