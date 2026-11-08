/* global axios */
import ApiClient from '../../ApiClient';

class WhatsappGroupsAPI extends ApiClient {
  constructor() {
    super('whatsapp_groups', { accountScoped: true });
  }

  create({ inboxId, subject, description, conversationId, autoInvite = true }) {
    return axios
      .post(this.url, {
        inbox_id: inboxId,
        subject,
        description,
        conversation_id: conversationId,
        auto_invite: autoInvite,
      })
      .then(r => r.data);
  }
}

export default new WhatsappGroupsAPI();
