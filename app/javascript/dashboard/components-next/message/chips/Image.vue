<script setup>
import { computed, ref } from 'vue';
import Icon from 'next/icon/Icon.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});
const hasError = ref(false);
const showGallery = ref(false);

const { filteredCurrentChatAttachments } = useMessageContext();

const handleError = () => {
  hasError.value = true;
};

const hasDataUrl = computed(
  () => Boolean(props.attachment?.dataUrl || props.attachment?.data_url)
);

const imageSrc = computed(
  () =>
    props.attachment?.dataUrl ||
    props.attachment?.data_url ||
    props.attachment?.thumbUrl ||
    props.attachment?.thumb_url ||
    ''
);

const onImageClick = () => {
  if (hasDataUrl.value) {
    showGallery.value = true;
  }
};
</script>

<template>
  <div
    class="size-[72px] overflow-hidden contain-content rounded-xl"
    :class="{ 'cursor-pointer': hasDataUrl }"
    @click="onImageClick"
  >
    <div
      v-if="hasError"
      class="flex flex-col items-center justify-center gap-1 text-xs text-center rounded-lg size-full bg-n-alpha-1 text-n-slate-11"
    >
      <Icon icon="i-lucide-circle-off" class="text-n-slate-11" />
      {{ $t('COMPONENTS.MEDIA.LOADING_FAILED') }}
    </div>
    <img
      v-else-if="imageSrc"
      class="object-cover w-full h-full skip-context-menu"
      :src="imageSrc"
      :alt="attachment.fileName || ''"
      :title="attachment.fileName || ''"
      @error="handleError"
    />
    <div
      v-else
      class="flex flex-col items-center justify-center p-1 text-xs text-center rounded-lg size-full bg-n-alpha-1 text-n-slate-11 gap-1"
      :title="attachment.fileName || ''"
    >
      <Icon icon="i-lucide-image" class="size-4 shrink-0 text-n-slate-11" />
      <span
        v-if="attachment.fileName"
        class="truncate w-full text-[10px] text-n-slate-11"
      >
        {{ attachment.fileName }}
      </span>
    </div>
  </div>
  <GalleryView
    v-if="showGallery && hasDataUrl"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleError"
    @close="() => (showGallery = false)"
  />
</template>
