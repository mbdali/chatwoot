import { ref, onMounted, onUnmounted, watch } from 'vue';
import { getPdfThumbnail } from 'dashboard/helper/pdfHelper';

const RETRY_DELAYS = [500, 1500];
const wait = ms =>
  new Promise(resolve => {
    setTimeout(resolve, ms);
  });

export const usePdfThumbnail = urlRef => {
  const isLoaded = ref(false);
  const isLoading = ref(false);
  const hasError = ref(false);
  const thumbnailUrl = ref('');
  const numPages = ref(null);
  const aspectRatio = ref(0.75);

  let isUnmounted = false;
  let loadToken = 0;

  onUnmounted(() => {
    isUnmounted = true;
  });

  const load = async () => {
    loadToken += 1;
    const currentToken = loadToken;
    const isStale = () => isUnmounted || currentToken !== loadToken;

    const url = typeof urlRef === 'string' ? urlRef : urlRef?.value;
    if (!url) return;

    isLoading.value = true;
    hasError.value = false;

    /* eslint-disable no-await-in-loop */
    for (let attempt = 0; attempt <= RETRY_DELAYS.length; attempt += 1) {
      if (isStale()) return;

      try {
        const data = await getPdfThumbnail(url);
        if (isStale()) return;

        if (data) {
          thumbnailUrl.value = data.thumbnailUrl;
          numPages.value = data.numPages;
          aspectRatio.value = data.aspectRatio || 0.75;
          isLoaded.value = true;
          isLoading.value = false;
          return;
        }
      } catch (e) {
        // Fall through to retry or error handling
      }

      if (isStale()) return;

      if (attempt < RETRY_DELAYS.length) {
        await wait(RETRY_DELAYS[attempt]);
        if (isStale()) return;
      }
    }
    /* eslint-enable no-await-in-loop */

    if (!isStale()) {
      hasError.value = true;
      isLoading.value = false;
    }
  };

  onMounted(load);

  if (typeof urlRef !== 'string') {
    watch(urlRef, load);
  }

  return {
    isLoaded,
    isLoading,
    hasError,
    thumbnailUrl,
    numPages,
    aspectRatio,
  };
};
