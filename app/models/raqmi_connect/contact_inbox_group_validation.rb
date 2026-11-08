# frozen_string_literal: true

# Raqmi Connect fork, prepended to ContactInbox (config/initializers/raqmi_connect.rb).
#
# Upstream ContactInbox#validate_whatsapp_source_id restricts source_id to 1-15 digit phone numbers
# or BSUIDs. This module extends the validator to also accept valid WhatsApp group identifiers (e.g. @g.us),
# allowing group conversations to be anchored to a ContactInbox without modifying upstream files.
module RaqmiConnect
  module ContactInboxGroupValidation
    private

    def validate_whatsapp_source_id
      return if RaqmiConnect::WhatsappGroupHelper.group_identifier?(source_id)

      super
    end
  end
end
