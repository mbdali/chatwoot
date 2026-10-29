# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaqmiConnect::ChatwootHubSilence do
  describe 'silencing ChatwootHub outbound communication' do
    it 'returns nil for sync_with_hub without making any HTTP request' do
      expect(RestClient).not_to receive(:post)
      expect(ChatwootHub.sync_with_hub).to be_nil
    end

    it 'returns nil for register_instance without making any HTTP request' do
      expect(RestClient).not_to receive(:post)
      expect(ChatwootHub.register_instance('Test Co', 'Admin', 'admin@example.com')).to be_nil
    end

    it 'returns nil for emit_event without making any HTTP request' do
      expect(RestClient).not_to receive(:post)
      expect(ChatwootHub.emit_event('account_created', { id: 1 })).to be_nil
    end

    it 'returns nil for send_push and send_push_with_response without making any HTTP request' do
      expect(RestClient).not_to receive(:post)
      expect(ChatwootHub.send_push({ token: 'test' })).to be_nil
      expect(ChatwootHub.send_push_with_response({ token: 'test' })).to be_nil
    end

    it 'returns nil for all support_config credentials to prevent live widget loading' do
      expect(ChatwootHub.support_config).to eq(
        support_website_token: nil,
        support_script_url: nil,
        support_identifier_hash: nil
      )
    end
  end
end
