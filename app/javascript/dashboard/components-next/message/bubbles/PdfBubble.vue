<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../provider.js';
import BaseBubble from './Base.vue';
import PdfCard from './PdfCard.vue';

const props = defineProps({
  attachment: {
    type: Object,
    default: null,
  },
});

const { attachments } = useMessageContext();

const targetAttachment = computed(() => {
  return props.attachment || attachments?.value?.[0] || {};
});
</script>

<template>
  <BaseBubble
    class="overflow-hidden !p-1.5 max-w-[340px] w-full"
    data-bubble-name="pdf"
  >
    <PdfCard :attachment="targetAttachment" />
  </BaseBubble>
</template>
