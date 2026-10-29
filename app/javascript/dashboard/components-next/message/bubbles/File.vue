<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';
import PdfBubble from './PdfBubble.vue';
import FileIcon from 'next/icon/FileIcon.vue';

const { attachments } = useMessageContext();

const { t } = useI18n();

const attachment = computed(() => {
  return attachments.value?.[0] || {};
});

const url = computed(() => {
  return attachment.value.dataUrl || attachment.value.data_url || '';
});

const fileName = computed(() => {
  if (url.value) {
    const filename = url.value.substring(url.value.lastIndexOf('/') + 1);
    return filename || t('CONVERSATION.UNKNOWN_FILE_TYPE');
  }
  return attachment.value.fileName || t('CONVERSATION.UNKNOWN_FILE_TYPE');
});

const fileType = computed(() => {
  const extension = attachment.value.extension;
  if (extension) return extension.toLowerCase();
  return fileName.value.split('.').pop()?.toLowerCase();
});

const isPdf = computed(() => !!url.value && fileType.value === 'pdf');
</script>

<template>
  <PdfBubble v-if="isPdf" :attachment="attachment" />
  <BaseAttachmentBubble
    v-else
    icon="i-teenyicons-user-circle-solid"
    icon-bg-color="bg-n-alpha-3 dark:bg-n-alpha-white"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.FILE"
    :content="decodeURI(fileName)"
    :action="
      url
        ? {
            href: url,
            label: $t('CONVERSATION.DOWNLOAD'),
          }
        : null
    "
  >
    <template #icon>
      <FileIcon :file-type="fileType" class="size-4" />
    </template>
  </BaseAttachmentBubble>
</template>
