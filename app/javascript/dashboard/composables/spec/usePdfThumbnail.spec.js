import { defineComponent, h, ref } from 'vue';
import { mount } from '@vue/test-utils';
import { usePdfThumbnail } from '../usePdfThumbnail';
import { getPdfThumbnail } from 'dashboard/helper/pdfHelper';

vi.mock('dashboard/helper/pdfHelper', () => ({
  getPdfThumbnail: vi.fn(),
}));

const mountComposable = urlRef => {
  let composable;
  const wrapper = mount(
    defineComponent({
      setup() {
        composable = usePdfThumbnail(urlRef);
        return () => h('div');
      },
    })
  );

  return { wrapper, composable };
};

describe('usePdfThumbnail', () => {
  const mockThumbnailData = {
    thumbnailUrl: 'data:image/jpeg;base64,mockThumbnailData',
    numPages: 5,
    aspectRatio: 0.7,
  };

  beforeEach(() => {
    vi.useFakeTimers();
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('loads thumbnail successfully on the first attempt', async () => {
    getPdfThumbnail.mockResolvedValueOnce(mockThumbnailData);

    const url = ref('https://example.com/sample.pdf');
    const { composable } = mountComposable(url);

    expect(composable.isLoading.value).toBe(true);

    await vi.advanceTimersByTimeAsync(0);

    expect(getPdfThumbnail).toHaveBeenCalledTimes(1);
    expect(getPdfThumbnail).toHaveBeenCalledWith('https://example.com/sample.pdf');
    expect(composable.isLoaded.value).toBe(true);
    expect(composable.hasError.value).toBe(false);
    expect(composable.isLoading.value).toBe(false);
    expect(composable.thumbnailUrl.value).toBe('data:image/jpeg;base64,mockThumbnailData');
    expect(composable.numPages.value).toBe(5);
    expect(composable.aspectRatio.value).toBe(0.7);
  });

  it('retries when getPdfThumbnail fails once and then succeeds on second attempt', async () => {
    getPdfThumbnail
      .mockRejectedValueOnce(new Error('First attempt failed'))
      .mockResolvedValueOnce(mockThumbnailData);

    const url = ref('https://example.com/sample.pdf');
    const { composable } = mountComposable(url);

    expect(composable.isLoading.value).toBe(true);
    expect(composable.isLoaded.value).toBe(false);
    expect(composable.hasError.value).toBe(false);

    // Initial attempt failed; backoff 500ms
    await vi.advanceTimersByTimeAsync(500);

    expect(getPdfThumbnail).toHaveBeenCalledTimes(2);
    expect(composable.isLoaded.value).toBe(true);
    expect(composable.hasError.value).toBe(false);
    expect(composable.isLoading.value).toBe(false);
    expect(composable.thumbnailUrl.value).toBe('data:image/jpeg;base64,mockThumbnailData');
  });

  it('retries when getPdfThumbnail returns null and succeeds on third attempt', async () => {
    getPdfThumbnail
      .mockResolvedValueOnce(null)
      .mockRejectedValueOnce(new Error('Second attempt failed'))
      .mockResolvedValueOnce(mockThumbnailData);

    const url = ref('https://example.com/sample.pdf');
    const { composable } = mountComposable(url);

    expect(composable.isLoading.value).toBe(true);

    // 1st retry after 500ms
    await vi.advanceTimersByTimeAsync(500);
    expect(composable.isLoading.value).toBe(true);
    expect(composable.isLoaded.value).toBe(false);

    // 2nd retry after 1500ms
    await vi.advanceTimersByTimeAsync(1500);

    expect(getPdfThumbnail).toHaveBeenCalledTimes(3);
    expect(composable.isLoaded.value).toBe(true);
    expect(composable.hasError.value).toBe(false);
    expect(composable.isLoading.value).toBe(false);
  });

  it('sets hasError to true after exhausting 3 total attempts', async () => {
    getPdfThumbnail.mockRejectedValue(new Error('Persistent network failure'));

    const url = ref('https://example.com/sample.pdf');
    const { composable } = mountComposable(url);

    expect(composable.isLoading.value).toBe(true);

    // 1st retry after 500ms
    await vi.advanceTimersByTimeAsync(500);
    expect(composable.isLoading.value).toBe(true);
    expect(composable.hasError.value).toBe(false);

    // 2nd retry after 1500ms
    await vi.advanceTimersByTimeAsync(1500);

    expect(getPdfThumbnail).toHaveBeenCalledTimes(3);
    expect(composable.isLoaded.value).toBe(false);
    expect(composable.hasError.value).toBe(true);
    expect(composable.isLoading.value).toBe(false);
  });

  it('drops stale results if component is unmounted during retry backoff', async () => {
    getPdfThumbnail.mockRejectedValueOnce(new Error('Failure'));

    const url = ref('https://example.com/sample.pdf');
    const { wrapper, composable } = mountComposable(url);

    // Attempt 1 fails, now in 500ms backoff
    await vi.advanceTimersByTimeAsync(0);
    expect(getPdfThumbnail).toHaveBeenCalledTimes(1);

    wrapper.unmount();

    // Advance past retry delay
    await vi.advanceTimersByTimeAsync(2000);

    expect(getPdfThumbnail).toHaveBeenCalledTimes(1);
    expect(composable.isLoaded.value).toBe(false);
    expect(composable.hasError.value).toBe(false);
  });

  it('cancels stale attempts when URL changes during retry backoff', async () => {
    const dataA = { thumbnailUrl: 'thumbA', numPages: 1, aspectRatio: 0.75 };
    const dataB = { thumbnailUrl: 'thumbB', numPages: 2, aspectRatio: 0.75 };

    getPdfThumbnail.mockImplementation(async targetUrl => {
      if (targetUrl === 'https://example.com/a.pdf') {
        throw new Error('Failure for A');
      }
      return dataB;
    });

    const url = ref('https://example.com/a.pdf');
    const { composable } = mountComposable(url);

    expect(composable.isLoading.value).toBe(true);

    // URL changes during retry backoff
    url.value = 'https://example.com/b.pdf';

    await vi.advanceTimersByTimeAsync(500);

    expect(composable.thumbnailUrl.value).toBe('thumbB');
    expect(composable.numPages.value).toBe(2);
    expect(composable.isLoaded.value).toBe(true);
    expect(composable.hasError.value).toBe(false);
    expect(composable.isLoading.value).toBe(false);
  });
});
