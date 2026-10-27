import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import {
  addMessageReaction,
  removeMessageReaction,
} from 'dashboard/api/raqmi_connect/reactions';

export const useMessageReactions = () => {
  const toggleReaction = async ({
    accountId,
    conversationId,
    messageId,
    emoji,
    currentUserId,
    existingReactions = [],
  }) => {
    const hasAlreadyReactedWithEmoji = existingReactions.some(
      r =>
        r.actor_type === 'User' &&
        Number(r.actor_id) === Number(currentUserId) &&
        r.emoji === emoji
    );

    try {
      if (hasAlreadyReactedWithEmoji) {
        await removeMessageReaction(accountId, conversationId, messageId);
      } else {
        await addMessageReaction(accountId, conversationId, messageId, emoji);
      }
    } catch (error) {
      useAlert(parseAPIErrorResponse(error));
    }
  };

  return {
    toggleReaction,
  };
};
