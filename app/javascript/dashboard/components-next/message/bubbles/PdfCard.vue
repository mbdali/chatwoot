<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { downloadFile, getFileInfo } from '@chatwoot/utils';
import { formatBytes } from 'shared/helpers/FileHelper';
import { usePdfThumbnail } from 'dashboard/composables/usePdfThumbnail';

import Button from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import PdfViewerModal from './PdfViewerModal.vue';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const showViewer = ref(false);
const isDownloading = ref(false);

const url = computed(() => {
  return props.attachment?.dataUrl || props.attachment?.data_url || '';
});

const fileDetails = computed(() => getFileInfo(url.value));

const fileName = computed(() => {
  if (url.value) {
    const filename = url.value.substring(url.value.lastIndexOf('/') + 1);
    return decodeURI(filename || t('CONVERSATION.UNKNOWN_FILE_TYPE'));
  }
  return t('CONVERSATION.UNKNOWN_FILE_TYPE');
});

const formattedSize = computed(() => {
  const bytes = props.attachment?.fileSize ?? props.attachment?.file_size;
  if (bytes && Number(bytes) > 0) {
    return formatBytes(Number(bytes), 1);
  }
  return '';
});

// Load first page thumbnail via client-side PDF.js (cached in-memory)
const { thumbnailUrl, numPages, isLoaded, hasError } = usePdfThumbnail(url);

const pageCountString = computed(() => {
  if (!numPages.value) return '';
  return numPages.value === 1
    ? `1 ${t('CONVERSATION.PAGE')}`
    : `${numPages.value} ${t('CONVERSATION.PAGES')}`;
});

const downloadAttachment = async () => {
  try {
    isDownloading.value = true;
    await downloadFile({ url: url.value, type: 'file', extension: 'pdf' });
  } catch (error) {
    window.open(url.value, '_blank');
  } finally {
    isDownloading.value = false;
  }
};

const openViewer = () => {
  showViewer.value = true;
};
</script>

<template>
  <div
    class="group relative flex flex-col rounded-xl overflow-hidden border border-n-weak/80 bg-n-surface-1 dark:bg-n-solid-2 shadow-sm cursor-pointer select-none transition-all duration-200 hover:shadow-md max-w-[320px] w-full"
    @click="openViewer"
  >
    <!-- Top: First Page Preview Section -->
    <div
      class="relative w-full h-[200px] flex items-center justify-center overflow-hidden bg-n-slate-2 dark:bg-n-slate-3 p-3"
    >
      <!-- Loading Shimmer State -->
      <div
        v-if="!isLoaded && !hasError"
        class="w-full h-full flex flex-col items-center justify-center gap-2 animate-pulse"
      >
        <div
          class="w-24 h-32 rounded bg-n-slate-4 dark:bg-n-slate-5 shadow-sm"
        />
        <span class="text-xs text-n-slate-10 font-medium">
          {{ $t('CONVERSATION.LOADING_PREVIEW') }}
        </span>
      </div>

      <!-- Rendered Page 1 Thumbnail -->
      <div
        v-else-if="thumbnailUrl"
        class="relative max-h-full flex items-center justify-center"
      >
        <img
          :src="thumbnailUrl"
          :alt="fileName"
          class="max-h-[176px] w-auto max-w-[88%] object-contain rounded-[2px] shadow-[0_2px_8px_rgba(0,0,0,0.15)] border border-black/5 dark:border-white/5"
        />
        <!-- Page Count Badge (e.g. 1 / 4) -->
        <div
          v-if="numPages"
          class="absolute top-1 right-1 bg-black/65 backdrop-blur-sm text-white text-[10px] font-semibold px-1.5 py-0.5 rounded shadow-sm"
        >
          1 / {{ numPages }}
        </div>
      </div>

      <!-- Fallback if rendering fails (e.g. CORS/protected PDF) -->
      <div
        v-else
        class="w-full h-full flex flex-col items-center justify-center gap-2 p-4 text-center"
      >
        <div
          class="w-14 h-16 rounded-lg bg-[#EA4335] text-white flex flex-col items-center justify-center shadow-md relative overflow-hidden"
        >
          <div
            class="absolute top-0 right-0 w-3.5 h-3.5 bg-black/20 rounded-bl-[3px]"
          />
          <Icon icon="i-lucide-file-text" class="size-6 mb-1" />
          <span class="text-[9px] font-extrabold tracking-wider">PDF</span>
        </div>
        <span class="text-xs text-n-slate-11 font-medium">
          {{ $t('CONVERSATION.CLICK_TO_VIEW_DOCUMENT') }}
        </span>
      </div>

      <!-- Hover Overlay with Action Buttons (matches Chatwoot Image bubble) -->
      <div
        class="inset-0 p-2 pointer-events-none absolute bg-gradient-to-t from-black/40 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity flex items-end justify-end gap-2"
      >
        <Button
          xs
          solid
          slate
          icon="i-lucide-expand"
          class="!size-7 !p-0 shadow-md pointer-events-auto bg-white/90 dark:bg-black/80 hover:bg-white text-n-slate-12"
          :title="$t('CONVERSATION.CLICK_TO_EXPAND')"
          @click.stop="openViewer"
        />
        <Button
          xs
          solid
          slate
          icon="i-lucide-download"
          class="!size-7 !p-0 shadow-md pointer-events-auto bg-white/90 dark:bg-black/80 hover:bg-white text-n-slate-12"
          :is-loading="isDownloading"
          :disabled="isDownloading"
          :title="$t('CONVERSATION.DOWNLOAD')"
          @click.stop="downloadAttachment"
        />
      </div>
    </div>

    <!-- Bottom: WhatsApp Document Info Banner -->
    <div
      class="flex items-center gap-3 px-3.5 py-2.5 bg-n-alpha-2 dark:bg-n-alpha-1 border-t border-n-weak/80 min-w-0"
    >
      <!-- Iconic Red PDF Badge -->
      <div
        class="relative w-8 h-9 rounded-md bg-[#EA4335] dark:bg-[#E53935] flex flex-col items-center justify-center text-white shadow-sm shrink-0 overflow-hidden"
      >
        <div
          class="absolute top-0 right-0 w-2 h-2 bg-black/20 rounded-bl-[2px]"
        />
        <span class="text-[8.5px] font-black tracking-wider mt-0.5">PDF</span>
        <div class="w-3.5 h-0.5 bg-white/40 rounded-full mt-0.5" />
      </div>

      <!-- Title & Subtitle -->
      <div class="flex-1 min-w-0 flex flex-col justify-center">
        <span
          class="text-xs font-semibold text-n-slate-12 truncate leading-snug"
          :title="fileName"
        >
          {{ fileName }}
        </span>
        <span
          class="text-[11px] text-n-slate-11 flex items-center gap-1 mt-0.5 leading-none"
        >
          <span v-if="pageCountString">{{ pageCountString }} •</span>
          <span v-if="formattedSize">{{ formattedSize }} •</span>
          <span class="font-bold text-red-600 dark:text-red-400">PDF</span>
        </span>
      </div>

      <!-- Download Action Button -->
      <Button
        xs
        ghost
        slate
        icon="i-lucide-download"
        class="shrink-0 text-n-slate-11 hover:text-n-slate-12 !p-1.5"
        :is-loading="isDownloading"
        :title="$t('CONVERSATION.DOWNLOAD')"
        @click.stop="downloadAttachment"
      />
    </div>
  </div>

  <!-- PDF Viewer Lightbox Modal -->
  <PdfViewerModal
    v-if="showViewer"
    v-model:show="showViewer"
    :url="url"
    :file-name="fileName"
    :file-size="formattedSize"
    :num-pages="numPages"
    @close="showViewer = false"
  />
</template>
