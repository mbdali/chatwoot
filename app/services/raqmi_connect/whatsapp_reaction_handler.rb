# frozen_string_literal: true

# Raqmi Connect fork: handles persisting WhatsApp reactions on message.content_attributes.
# Zero schema changes: stores array of reactions in existing content_attributes JSON column.
module RaqmiConnect
  class WhatsappReactionHandler
    pattr_initialize [:inbox!, :target_source_id, :target_message, :emoji, :actor, :actor_type, :source_id, :timestamp]

    def perform
      message = target_message || find_target_message
      return unless message

      message.with_lock do
        attrs = (message.content_attributes || {}).deep_dup
        reactions = Array(attrs['reactions'] || attrs[:reactions]).map { |r| r.to_h.deep_stringify_keys }

        actor_id_val = actor&.id
        effective_type = actor_type.to_s

        existing_index = reactions.find_index do |r|
          matches_actor?(r, effective_type, actor_id_val)
        end

        clean_emoji = emoji.to_s.strip

        if clean_emoji.present?
          new_reaction = {
            'emoji' => clean_emoji,
            'actor_type' => effective_type,
            'actor_id' => actor_id_val,
            'actor_name' => actor&.name || default_actor_name(effective_type),
            'source_id' => source_id,
            'created_at' => formatted_timestamp
          }.compact

          if existing_index
            reactions[existing_index] = new_reaction
          else
            reactions << new_reaction
          end
        elsif existing_index
          reactions.delete_at(existing_index)
        end

        attrs['reactions'] = reactions
        message.content_attributes = attrs
        message.save!
      end

      message
    end

    private

    def matches_actor?(reaction, effective_type, actor_id_val)
      return false unless reaction['actor_type'].to_s == effective_type

      if actor_id_val.present?
        reaction['actor_id'] == actor_id_val
      else
        reaction['actor_id'].nil?
      end
    end

    def default_actor_name(effective_type)
      effective_type == 'Contact' ? 'Contact' : 'Agent'
    end

    def find_target_message
      return if target_source_id.blank?

      inbox.messages.find_by(source_id: target_source_id) ||
        inbox.account.messages.find_by(source_id: target_source_id)
    end

    def formatted_timestamp
      if timestamp.present?
        Time.at(timestamp.to_i).utc.iso8601
      else
        Time.current.utc.iso8601
      end
    end
  end
end
