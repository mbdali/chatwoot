import { ref, onMounted, watch } from 'vue';
import { getPdfThumbnail } from 'dashboard/helper/pdfHelper';

export const usePdfThumbnail = urlRef => {
  const isLoaded = ref(false);
  const isLoading = ref(false);
  const hasError = ref(false);
  const thumbnailUrl = ref('');
  const numPages = ref(null);
  const aspectRatio = ref(0.75);

  const load = async () => {
    const url = typeof urlRef === 'string' ? urlRef : urlRef?.value;
    if (!url) return;

    isLoading.value = true;
    hasError.value = false;

    try {
      const data = await getPdfThumbnail(url);
      if (data) {
        thumbnailUrl.value = data.thumbnailUrl;
        numPages.value = data.numPages;
        aspectRatio.value = data.aspectRatio || 0.75;
        isLoaded.value = true;
      } else {
        hasError.value = true;
      }
    } catch (e) {
      hasError.value = true;
    } finally {
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
