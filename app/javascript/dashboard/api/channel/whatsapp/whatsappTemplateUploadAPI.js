/* global axios */
import ApiClient from '../../ApiClient';

class WhatsappTemplateUploadAPI extends ApiClient {
  constructor() {
    super('whatsapp_templates', { accountScoped: true });
  }

  uploadMedia(file) {
    const formData = new FormData();
    formData.append('file', file);

    return axios
      .post(`${this.url}/upload_media`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      })
      .then(response => response.data);
  }
}

export default new WhatsappTemplateUploadAPI();
