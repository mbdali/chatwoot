# frozen_string_literal: true

# Raqmi Connect fork, prepended to Webhooks::WhatsappEventsJob (config/initializers/raqmi_connect.rb).
#
# When an incoming webhook payload represents a WhatsApp group event or message, serialize the
# job lock on the group_id instead of the individual participant phone number. This prevents
# concurrent messages from multiple participants in the same group from racing to create conversations.
module RaqmiConnect
  module WhatsappEventsJobGroupLock
    def contact_sender_id(params)
      value = params.dig(:entry, 0, :changes, 0, :value) || params
      group_id = RaqmiConnect::WhatsappGroupHelper.extract_group_id(value)
      return group_id if group_id.present?

      super
    end
  end
end
