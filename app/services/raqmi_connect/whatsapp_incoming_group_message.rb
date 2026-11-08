# frozen_string_literal: true

# Raqmi Connect fork, prepended to Whatsapp::IncomingMessageBaseService (config/initializers/raqmi_connect.rb).
#
# Intercepts WhatsApp group messages, lifecycle events, and participant events:
# 1. Resolves/creates a single Group Contact & ContactInbox using the group_id so all
#    participants share the exact same conversation thread.
# 2. Formats incoming group messages before DB save: attaches sender metadata in content_attributes
#    and prefixes content with [Sender Name] for clear agent visibility across all platforms in a single atomic INSERT.
# 3. Handles group lifecycle (create/delete) and participant (join/leave) webhook events,
#    recording activity messages in the conversation timeline.
#
# Zero schema changes: utilizes existing source_id and jsonb columns.
module RaqmiConnect
  module WhatsappIncomingGroupMessage
    def perform
      processed_params
      return process_group_event if group_lifecycle_or_participant_event?

      super
    end

    private

    def group_message?
      current_group_id.present?
    end

    def current_group_id
      return @current_group_id if defined?(@current_group_id)

      @current_group_id = RaqmiConnect::WhatsappGroupHelper.extract_group_id(messages_data&.first || processed_params)
    end

    def set_contact
      return super unless group_message?

      @contact_inbox = find_or_build_group_contact(current_group_id)
      @contact = @contact_inbox.contact
    end

    def conversation_params
      params_hash = super
      if group_message?
        params_hash[:additional_attributes] = (params_hash[:additional_attributes] || {}).merge(
          'is_group' => true,
          'group_id' => current_group_id
        )
      end
      params_hash
    end

    def set_conversation
      super
      if group_message? && @conversation.present? && !@conversation.additional_attributes&.dig('is_group')
        @conversation.update!(
          additional_attributes: (@conversation.additional_attributes || {}).merge(
            'is_group' => true,
            'group_id' => current_group_id
          )
        )
      end
    end

    def message_content_attributes(message)
      attrs = super
      return attrs unless group_message?

      attrs[:is_group] = true
      attrs[:group_id] = current_group_id
      attrs[:group_sender] = extract_group_sender_info unless outgoing_echo
      attrs
    end

    def create_regular_message(message)
      return super unless group_message?

      create_message(message, source_id: message[:id])
      attach_files
      attach_location if message_type == 'location'
      format_group_message_before_save!
      @message.save!
    end

    def create_unsupported_message(message)
      return super unless group_message?

      log_error(message) if error_webhook_event?(message)
      process_in_reply_to(message)
      create_message(message, source_id: message[:id])
      @message.content = I18n.t('conversations.messages.whatsapp.unsupported_message')
      @message.content_attributes = @message.content_attributes.merge(is_unsupported: true)
      format_group_message_before_save!
      @message.save!
    end

    def format_group_message_before_save!
      return if @message.blank?

      sender_info = extract_group_sender_info
      attrs = (@message.content_attributes || {}).merge(
        'is_group' => true,
        'group_id' => current_group_id
      )
      attrs['group_sender'] = sender_info unless outgoing_echo
      @message.content_attributes = attrs

      return if outgoing_echo || sender_info[:name].blank?

      prefix = "[#{sender_info[:name]}]: "
      if @message.content.present?
        @message.content = "#{prefix}#{@message.content}" unless @message.content.start_with?(prefix)
      elsif message_type == 'location'
        loc_name = @message.attachments.first&.fallback_title
        @message.content = "#{prefix}#{loc_name.presence || 'shared a location'}"
      elsif @message.attachments.present?
        @message.content = "#{prefix}sent an attachment"
      end
    end

    def extract_group_sender_info
      return @group_sender_info if defined?(@group_sender_info)

      msg = messages_data&.first || {}
      sender_phone = msg[:from].to_s.presence
      sender_user_id = msg[:from_user_id].to_s.presence

      contacts = Array(processed_params[:contacts])
      contact_entry = contacts.find do |c|
        (sender_phone.present? && c[:wa_id].to_s == sender_phone) ||
          (sender_user_id.present? && c[:user_id].to_s == sender_user_id)
      end

      profile_name = contact_entry&.dig(:profile, :name).presence
      display_name = profile_name || sender_phone || sender_user_id || 'Member'

      @group_sender_info = {
        name: display_name,
        phone_number: sender_phone,
        user_id: sender_user_id
      }.compact
    end

    def find_or_build_group_contact(group_id, subject: nil, invite_link: nil, description: nil)
      contact_inbox = inbox.contact_inboxes.find_by(source_id: group_id)
      name = subject.presence ||
             RaqmiConnect::WhatsappGroupHelper.extract_group_subject(processed_params).presence ||
             contact_inbox&.contact&.name.presence ||
             "WhatsApp Group (#{group_id.to_s.truncate(20)})"

      if contact_inbox.blank?
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

        contact_inbox = ::ContactInboxWithContactBuilder.new(
          inbox: inbox,
          contact_attributes: contact_attributes,
          source_id: group_id
        ).perform
      else
        contact = contact_inbox.contact
        current_attrs = contact.additional_attributes || {}
        updates = {}
        updates[:name] = subject if subject.present? && contact.name != subject
        new_attrs = current_attrs.merge('is_group' => true, 'group_id' => group_id)
        new_attrs['invite_link'] = invite_link if invite_link.present?
        new_attrs['description'] = description if description.present?
        updates[:additional_attributes] = new_attrs if new_attrs != current_attrs
        contact.update!(updates) if updates.present?
      end

      contact_inbox
    end

    def find_or_create_group_conversation(contact_inbox, group_id)
      conversation = if inbox.lock_to_single_conversation
                       contact_inbox.conversations.last
                     else
                       contact_inbox.conversations.where.not(status: :resolved).last
                     end
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

    def group_lifecycle_or_participant_event?
      field = params.dig(:entry, 0, :changes, 0, :field).to_s
      return true if %w[group_lifecycle_update group_participants_update group_settings_update].include?(field)

      processed_params[:groups].present? ||
        (processed_params[:group].present? && processed_params[:event].present?)
    end

    def process_group_event
      field = params.dig(:entry, 0, :changes, 0, :field).to_s

      if field == 'group_lifecycle_update' || processed_params[:groups].present?
        process_group_lifecycle_event
      elsif field == 'group_participants_update' || (processed_params[:group].present? && processed_params[:event].present?)
        process_group_participants_event
      elsif field == 'group_settings_update'
        process_group_settings_event
      end
    end

    def process_group_lifecycle_event
      groups = Array(processed_params[:groups] || processed_params[:group])
      groups.each do |group_data|
        group_id = group_data[:group_id] || group_data[:id]
        next if group_id.blank?

        subject = group_data[:subject]
        invite_link = group_data[:invite_link]
        description = group_data[:description]

        contact_inbox = find_or_build_group_contact(group_id, subject: subject, invite_link: invite_link, description: description)
        conversation = find_or_create_group_conversation(contact_inbox, group_id)

        case group_data[:type].to_s
        when 'group_create'
          text = "WhatsApp group created: #{subject.presence || group_id}"
          text += " (Invite link: #{invite_link})" if invite_link.present?
          create_group_activity_message(conversation, text)
        when 'group_delete'
          create_group_activity_message(conversation, 'WhatsApp group was deleted.')
          conversation.resolved! if conversation.status != 'resolved'
        end
      end
    end

    def process_group_participants_event
      group_data = processed_params[:group] || {}
      group_id = group_data[:id] || group_data[:group_id]
      return if group_id.blank?

      event = processed_params[:event].to_s.upcase
      participants = Array(processed_params[:participants] || group_data[:participants])

      contact_inbox = find_or_build_group_contact(group_id)
      conversation = find_or_create_group_conversation(contact_inbox, group_id)

      labels = participants.map { |p| p[:wa_id].presence || p[:user_id].presence || 'Participant' }.compact_blank.join(', ')

      case event
      when 'JOIN'
        create_group_activity_message(conversation, "#{labels.presence || 'A participant'} joined the group.")
      when 'LEAVE', 'REMOVE'
        create_group_activity_message(conversation, "#{labels.presence || 'A participant'} left the group.")
      else
        create_group_activity_message(conversation, "Group participants updated: #{event} (#{labels}).")
      end
    end

    def process_group_settings_event
      group_data = processed_params[:group] || {}
      group_id = group_data[:id] || processed_params[:group_id]
      return if group_id.blank?

      subject = group_data[:subject] || processed_params[:subject]
      contact_inbox = find_or_build_group_contact(group_id, subject: subject)
      return if subject.blank?

      conversation = find_or_create_group_conversation(contact_inbox, group_id)
      create_group_activity_message(conversation, "Group subject changed to: #{subject}")
    end

    def create_group_activity_message(conversation, content)
      conversation.messages.create!(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        message_type: :activity,
        content: content
      )
    rescue StandardError => e
      Rails.logger.warn("[WHATSAPP GROUP ACTIVITY ERROR] #{e.message}")
    end
  end
end
