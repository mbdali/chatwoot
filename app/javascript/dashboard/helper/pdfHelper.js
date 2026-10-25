/**
 * PDF Helper for client-side first-page thumbnail generation and metadata extraction.
 * Uses local Mozilla PDF.js (/pdfjs/pdf.min.js) with fallback to CDN.
 */

const thumbnailCache = new Map();
let pdfjsLoadPromise = null;

export const loadPdfJs = () => {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('Window not available'));
  }
  if (window.pdfjsLib) {
    return Promise.resolve(window.pdfjsLib);
  }
  if (pdfjsLoadPromise) {
    return pdfjsLoadPromise;
  }

  pdfjsLoadPromise = new Promise((resolve, reject) => {
    const existingScript = document.querySelector('script[data-pdfjs="true"]');
    if (existingScript) {
      if (window.pdfjsLib) {
        resolve(window.pdfjsLib);
        return;
      }
      existingScript.addEventListener('load', () => resolve(window.pdfjsLib));
      existingScript.addEventListener('error', reject);
      return;
    }

    const script = document.createElement('script');
    script.src = '/pdfjs/pdf.min.js';
    script.async = true;
    script.setAttribute('data-pdfjs', 'true');

    script.onload = () => {
      if (window.pdfjsLib) {
        window.pdfjsLib.GlobalWorkerOptions.workerSrc =
          '/pdfjs/pdf.worker.min.js';
        resolve(window.pdfjsLib);
      } else {
        reject(new Error('pdfjsLib is not defined'));
      }
    };

    script.onerror = () => {
      // Fallback to CDN if local bundle is not reachable
      const cdnScript = document.createElement('script');
      cdnScript.src =
        'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
      cdnScript.async = true;
      cdnScript.setAttribute('data-pdfjs', 'true');

      cdnScript.onload = () => {
        if (window.pdfjsLib) {
          window.pdfjsLib.GlobalWorkerOptions.workerSrc =
            'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
          resolve(window.pdfjsLib);
        } else {
          reject(new Error('pdfjsLib CDN failed'));
        }
      };

      cdnScript.onerror = reject;
      document.head.appendChild(cdnScript);
    };

    document.head.appendChild(script);
  });

  return pdfjsLoadPromise;
};

/**
 * Generate a high-resolution first page preview image and page count for a given PDF URL.
 * Results are cached in memory for zero-overhead re-renders.
 *
 * @param {string} url - URL or blob URL of the PDF
 * @param {number} targetWidth - Width in pixels for the generated thumbnail
 * @returns {Promise<{ thumbnailUrl: string, numPages: number, aspectRatio: number }>}
 */
export const getPdfThumbnail = async (url, targetWidth = 420) => {
  if (!url) return null;
  if (thumbnailCache.has(url)) {
    return thumbnailCache.get(url);
  }

  const pdfjs = await loadPdfJs();
  const loadingTask = pdfjs.getDocument({
    url,
    withCredentials: false,
    disableRange: false,
    disableAutoFetch: true,
  });

  const pdf = await loadingTask.promise;
  const numPages = pdf.numPages || 1;
  const page = await pdf.getPage(1);

  // Calculate scaling for sharp rendering
  const unscaledViewport = page.getViewport({ scale: 1 });
  const scale = targetWidth / unscaledViewport.width;
  const viewport = page.getViewport({ scale });

  const canvas = document.createElement('canvas');
  canvas.width = Math.floor(viewport.width);
  canvas.height = Math.floor(viewport.height);
  const context = canvas.getContext('2d', { alpha: false });

  // Pre-fill canvas with white (standard document sheet)
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);

  await page.render({
    canvasContext: context,
    viewport,
  }).promise;

  const thumbnailUrl = canvas.toDataURL('image/jpeg', 0.85);
  const result = {
    thumbnailUrl,
    numPages,
    aspectRatio: viewport.width / viewport.height,
  };

  thumbnailCache.set(url, result);
  return result;
};
