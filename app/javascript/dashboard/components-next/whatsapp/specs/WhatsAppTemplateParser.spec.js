import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';

import WhatsAppTemplateParser from '../WhatsAppTemplateParser.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const template = {
  name: 'token_values',
  category: 'UTILITY',
  language: 'en',
  parameter_format: 'POSITIONAL',
  components: [
    {
      type: 'BODY',
      text: '{{1}} / {{2}}',
      example: {
        body_text: [['First', 'Second']],
      },
    },
  ],
};

describe('WhatsAppTemplateParser', () => {
  let wrapper;

  beforeEach(async () => {
    wrapper = shallowMount(WhatsAppTemplateParser, {
      props: { template },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    wrapper.vm.processedParams.body['1'] = '{{2}}';
    wrapper.vm.processedParams.body['2'] = 'Bob';
    await nextTick();
  });

  it('sends the original template body instead of the rendered preview', () => {
    expect(wrapper.vm.renderedTemplate).toBe('{{2}} / Bob');

    wrapper.vm.sendMessage();

    expect(wrapper.emitted('sendMessage')[0][0]).toMatchObject({
      message: '{{1}} / {{2}}',
      pendingMessageContent: '{{2}} / Bob',
      templateParams: {
        content_mode: 'raw_template',
        processed_params: {
          body: {
            1: '{{2}}',
            2: 'Bob',
          },
        },
      },
    });
  });

  it('sends rendered content when requested for an API inbox template', async () => {
    await wrapper.setProps({ sendRenderedContent: true });

    wrapper.vm.sendMessage();

    expect(wrapper.emitted('sendMessage')[0][0]).toMatchObject({
      message: '{{2}} / Bob',
      pendingMessageContent: '{{2}} / Bob',
      templateParams: {
        content_mode: 'rendered',
      },
    });
  });

  it('sends template parameters with media_url, media_name, and blob_signed_id', async () => {
    const mediaTemplate = {
      name: 'invoice_receipt',
      category: 'UTILITY',
      language: 'en',
      components: [
        {
          type: 'HEADER',
          format: 'DOCUMENT',
        },
        {
          type: 'BODY',
          text: 'Here is your receipt',
        },
      ],
    };

    const mediaWrapper = shallowMount(WhatsAppTemplateParser, {
      props: { template: mediaTemplate },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    mediaWrapper.vm.updateMediaUrl('https://storage.example.com/receipt.pdf');
    mediaWrapper.vm.updateMediaName('Invoice_2026.pdf');
    mediaWrapper.vm.updateBlobSignedId('signed_blob_abc123');
    await nextTick();

    mediaWrapper.vm.sendMessage();

    expect(mediaWrapper.emitted('sendMessage')[0][0]).toMatchObject({
      message: 'Here is your receipt',
      templateParams: {
        name: 'invoice_receipt',
        processed_params: {
          header: {
            media_url: 'https://storage.example.com/receipt.pdf',
            media_name: 'Invoice_2026.pdf',
            blob_signed_id: 'signed_blob_abc123',
          },
        },
      },
    });
  });
});
