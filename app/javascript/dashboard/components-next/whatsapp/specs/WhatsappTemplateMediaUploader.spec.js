import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import WhatsappTemplateMediaUploader from '../WhatsappTemplateMediaUploader.vue';
import whatsappTemplateUploadAPI from 'dashboard/api/channel/whatsapp/whatsappTemplateUploadAPI';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/api/channel/whatsapp/whatsappTemplateUploadAPI', () => ({
  default: {
    uploadMedia: vi.fn(),
  },
}));

describe('WhatsappTemplateMediaUploader', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(WhatsappTemplateMediaUploader, {
      props: {
        mediaFormat: 'IMAGE',
        mediaUrl: '',
        mediaName: '',
        blobSignedId: '',
        isDocumentTemplate: false,
        ...props,
      },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });
  };

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('renders upload mode by default when no URL is present', () => {
    wrapper = createComponent();
    expect(wrapper.vm.activeTab).toBe('upload');
  });

  it('defaults to url mode when mediaUrl is present without blobSignedId', () => {
    wrapper = createComponent({
      mediaUrl: 'https://example.com/image.png',
      blobSignedId: '',
    });
    expect(wrapper.vm.activeTab).toBe('url');
  });

  it('uploads a file successfully and emits events', async () => {
    whatsappTemplateUploadAPI.uploadMedia.mockResolvedValueOnce({
      file_url: 'https://storage.example.com/receipt.png',
      file_name: 'receipt.png',
      file_size: 1024,
      blob_signed_id: 'blob_sig_123',
    });

    wrapper = createComponent();

    const file = new File(['dummy content'], 'receipt.png', {
      type: 'image/png',
    });

    await wrapper.vm.processUpload(file);
    await nextTick();

    expect(whatsappTemplateUploadAPI.uploadMedia).toHaveBeenCalledWith(file);
    expect(wrapper.emitted('update:mediaUrl')[0]).toEqual([
      'https://storage.example.com/receipt.png',
    ]);
    expect(wrapper.emitted('update:blobSignedId')[0]).toEqual(['blob_sig_123']);
  });

  it('auto-populates mediaName for document templates when empty', async () => {
    whatsappTemplateUploadAPI.uploadMedia.mockResolvedValueOnce({
      file_url: 'https://storage.example.com/doc.pdf',
      file_name: 'contract.pdf',
      file_size: 2048,
      blob_signed_id: 'blob_doc_123',
    });

    wrapper = createComponent({
      mediaFormat: 'DOCUMENT',
      isDocumentTemplate: true,
      mediaName: '',
    });

    const file = new File(['pdf data'], 'contract.pdf', {
      type: 'application/pdf',
    });

    await wrapper.vm.processUpload(file);
    await nextTick();

    expect(wrapper.emitted('update:mediaName')[0]).toEqual(['contract.pdf']);
  });

  it('blocks upload if file exceeds max size limit', async () => {
    wrapper = createComponent({
      mediaFormat: 'IMAGE', // limit is 5MB
    });

    const largeFile = new File([''], 'huge.png', { type: 'image/png' });
    Object.defineProperty(largeFile, 'size', { value: 6 * 1024 * 1024 });

    await wrapper.vm.processUpload(largeFile);
    await nextTick();

    expect(whatsappTemplateUploadAPI.uploadMedia).not.toHaveBeenCalled();
    expect(wrapper.vm.uploadError).toBe(
      'WHATSAPP_TEMPLATES.PARSER.FILE_SIZE_LIMIT'
    );
  });

  it('clears data and emits empty values on remove', () => {
    wrapper = createComponent({
      mediaUrl: 'https://storage.example.com/receipt.png',
      blobSignedId: 'blob_123',
      mediaName: 'receipt.png',
    });

    wrapper.vm.handleRemove();

    expect(wrapper.emitted('update:mediaUrl')[0]).toEqual(['']);
    expect(wrapper.emitted('update:blobSignedId')[0]).toEqual(['']);
    expect(wrapper.emitted('update:mediaName')[0]).toEqual(['']);
  });

  it('emits updated mediaUrl and clears blobSignedId when URL input changes', () => {
    wrapper = createComponent();

    wrapper.vm.handleUrlChange('https://external.com/image.jpg');

    expect(wrapper.emitted('update:mediaUrl')[0]).toEqual([
      'https://external.com/image.jpg',
    ]);
    expect(wrapper.emitted('update:blobSignedId')[0]).toEqual(['']);
  });
});
