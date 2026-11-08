# frozen_string_literal: true

# Raqmi Connect fork: service for programmatic creation and invitation management of WhatsApp groups
# via Meta WhatsApp Cloud API.
class RaqmiConnect::WhatsappGroupService
  pattr_initialize [:inbox!]

  def create_group(subject:, description: nil)
    validate_whatsapp_cloud_inbox!

    group_id, invite_link = request_group_creation(subject: subject, description: description)
    contact_inbox = find_or_build_group_contact(group_id, subject: subject, invite_link: invite_link, description: description)
    conversation = find_or_create_group_conversation(contact_inbox, group_id)

    create_group_creation_activity(conversation, subject: subject, invite_link: invite_link)

    {
      group_id: group_id,
      subject: subject,
      description: description,
      invite_link: invite_link,
      contact_id: contact_inbox.contact_id,
      conversation_id: conversation.id
    }
  end

  def fetch_or_reset_invite_link(group_id)
    return if group_id.blank?

    url = "#{api_base_path}/v22.0/#{group_id}/invite_link"
    response = HTTParty.post(url, headers: api_headers)
    if response.success? && response.parsed_response.is_a?(Hash)
      return response.parsed_response['invite_link'] || response.parsed_response.dig('group', 'invite_link')
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("[WHATSAPP GROUP INVITE LINK ERROR] #{e.message}")
    nil
  end

  def send_invite_to_conversation(conversation, invite_link:, subject:)
    return unless conversation.present? && invite_link.present?

    message_body = "You are invited to join our WhatsApp group '#{subject}': #{invite_link}"
    message = conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: message_body
    )

    inbox.channel.send_message(conversation.contact_inbox.source_id, message) if conversation.can_reply?

    message
  end

  private

  def channel
    inbox.channel
  end

  def phone_number_id
    channel.provider_config['phone_number_id']
  end

  def api_base_path
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end

  def api_headers
    {
      'Authorization' => "Bearer #{channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end

  def validate_whatsapp_cloud_inbox!
    return if channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'

    raise CustomExceptions::WhatsappGroupError, 'Group creation is only supported on WhatsApp Cloud API inboxes.'
  end

  def request_group_creation(subject:, description: nil)
    payload = build_group_creation_payload(subject: subject, description: description)
    url = "#{api_base_path}/v22.0/#{phone_number_id}/groups"
    response = HTTParty.post(url, headers: api_headers, body: payload.to_json)

    handle_group_creation_error!(response) unless response.success?

    parse_group_creation_response(response)
  end

  def build_group_creation_payload(subject:, description: nil)
    payload = { messaging_product: 'whatsapp', subject: subject.to_s.strip }
    payload[:description] = description.to_s.strip if description.present?
    payload
  end

  def handle_group_creation_error!(response)
    error_msg = response.parsed_response.is_a?(Hash) ? response.parsed_response.dig('error', 'message') : nil
    raise CustomExceptions::WhatsappGroupError, error_msg || "Failed to create WhatsApp group (HTTP #{response.code})"
  end

  def parse_group_creation_response(response)
    data = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    group_id = data.dig('group', 'id') || data['id'] || data['group_id']
    invite_link = data.dig('group', 'invite_link') || data['invite_link'] || fetch_or_reset_invite_link(group_id)

    [group_id, invite_link]
  end

  def create_group_creation_activity(conversation, subject:, invite_link:)
    activity_text = "WhatsApp group '#{subject}' created."
    activity_text += " Invite link: #{invite_link}" if invite_link.present?
    conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :activity,
      content: activity_text
    )
  end

  def find_or_build_group_contact(group_id, subject: nil, invite_link: nil, description: nil)
    contact_inbox = inbox.contact_inboxes.find_by(source_id: group_id)
    name = subject.presence || "WhatsApp Group (#{group_id.to_s.truncate(20)})"

    if contact_inbox.blank?
      create_new_group_contact_inbox(group_id, name: name, invite_link: invite_link, description: description)
    else
      update_existing_group_contact(contact_inbox.contact, name: name, group_id: group_id, invite_link: invite_link, description: description)
      contact_inbox
    end
  end

  def create_new_group_contact_inbox(group_id, name:, invite_link:, description:)
    contact_attributes = {
      name: name,
      identifier: "whatsapp_group_#{group_id}",
      additional_attributes: {
        is_group: true,
        group_id: group_id,
        invite_link: invite_link,
        description: description
      }.compact
    }

    ::ContactInboxWithContactBuilder.new(
      inbox: inbox,
      contact_attributes: contact_attributes,
      source_id: group_id
    ).perform
  end

  def update_existing_group_contact(contact, name:, group_id:, invite_link:, description:)
    attrs = (contact.additional_attributes || {}).merge('is_group' => true, 'group_id' => group_id)
    attrs['invite_link'] = invite_link if invite_link.present?
    attrs['description'] = description if description.present?
    contact.update!(name: name, additional_attributes: attrs)
  end

  def find_or_create_group_conversation(contact_inbox, group_id)
    conversation = contact_inbox.conversations.where.not(status: :resolved).last || contact_inbox.conversations.last
    return conversation if conversation.present?

    ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      additional_attributes: {
        is_group: true,
        group_id: group_id
      }
    )
  end
end
