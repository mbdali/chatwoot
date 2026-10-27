<script setup>
defineProps({
  activeEmoji: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['select', 'close']);

const QUICK_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

const onSelectEmoji = emoji => {
  emit('select', emoji);
};
</script>

<template>
  <div
    v-on-click-outside="() => emit('close')"
    class="flex items-center gap-0.5 px-1.5 py-1 bg-n-solid-1 dark:bg-n-solid-2 border border-n-strong rounded-full shadow-lg z-20 backdrop-blur-sm animate-in fade-in zoom-in-95 duration-100"
  >
    <button
      v-for="emoji in QUICK_EMOJIS"
      :key="emoji"
      type="button"
      class="w-7 h-7 flex items-center justify-center text-base rounded-full hover:bg-n-alpha-2 hover:scale-125 transition-all duration-150 active:scale-95 cursor-pointer"
      :class="{
        'bg-n-brand/15 ring-1 ring-n-brand/50': activeEmoji === emoji,
      }"
      @click.stop="onSelectEmoji(emoji)"
    >
      {{ emoji }}
    </button>
  </div>
</template>
