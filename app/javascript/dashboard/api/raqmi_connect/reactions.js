/* global axios */

const buildUrl = (accountId, conversationId, messageId) => {
  return `/api/v1/accounts/${accountId}/conversations/${conversationId}/messages/${messageId}/reaction`;
};

export const addMessageReaction = (
  accountId,
  conversationId,
  messageId,
  emoji
) => {
  return axios.post(buildUrl(accountId, conversationId, messageId), { emoji });
};

export const removeMessageReaction = (accountId, conversationId, messageId) => {
  return axios.delete(buildUrl(accountId, conversationId, messageId));
};

export default {
  addMessageReaction,
  removeMessageReaction,
};
