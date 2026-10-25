<script setup>
import { ref, onMounted, onUnmounted, useTemplateRef } from 'vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  isFetching: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['clear', 'search']);

const searchQuery = defineModel({
  type: String,
  default: '',
});

const searchInputRef = useTemplateRef('searchInputRef');
const isFocused = ref(false);

const handleKeydown = e => {
  const isTargetEditable =
    ['INPUT', 'TEXTAREA'].includes(e.target.tagName) ||
    e.target.isContentEditable;

  const isSearchShortcut =
    (e.key === '/' && !isTargetEditable) ||
    ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k');

  if (isSearchShortcut) {
    e.preventDefault();
    searchInputRef.value?.focus();
  } else if (
    e.key === 'Escape' &&
    document.activeElement === searchInputRef.value
  ) {
    e.preventDefault();
    if (searchQuery.value) {
      clear();
    } else {
      searchInputRef.value?.blur();
    }
  }
};

const clear = () => {
  searchQuery.value = '';
  emit('clear');
  searchInputRef.value?.focus();
};

const onInput = e => {
  emit('search', e.target.value);
};

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});

defineExpose({
  focus: () => searchInputRef.value?.focus(),
  clear,
});
</script>

<template>
  <div class="px-3 pt-1 pb-2">
    <div
      class="flex items-center gap-2 px-3 h-9 rounded-lg bg-n-alpha-2 dark:bg-n-solid-2 border border-transparent focus-within:border-n-brand focus-within:bg-n-solid-1 dark:focus-within:bg-n-solid-1 focus-within:ring-1 focus-within:ring-n-brand/20 transition-all duration-150"
      :class="{
        'border-n-brand bg-n-solid-1 dark:bg-n-solid-1 ring-1 ring-n-brand/20':
          isFocused,
      }"
    >
      <button
        v-if="searchQuery"
        type="button"
        class="text-n-slate-10 hover:text-n-slate-12 shrink-0 transition-colors p-0.5 -ms-1 rounded hover:bg-n-alpha-2"
        :title="$t('CHAT_LIST.SEARCH.BACK')"
        @click="clear"
      >
        <span class="i-lucide-arrow-left size-4 block text-n-slate-11" />
      </button>
      <span
        v-else
        class="i-lucide-search size-4 text-n-slate-10 shrink-0"
      />
      <input
        ref="searchInputRef"
        v-model="searchQuery"
        type="text"
        class="w-full bg-transparent border-none text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-0 p-0 reset-base"
        :placeholder="$t('CHAT_LIST.SEARCH.PLACEHOLDER')"
        @input="onInput"
        @focus="isFocused = true"
        @blur="isFocused = false"
      />
      <Spinner
        v-if="isFetching"
        :size="16"
        class="text-n-brand shrink-0"
      />
      <button
        v-else-if="searchQuery"
        type="button"
        class="text-n-slate-10 hover:text-n-slate-12 shrink-0 transition-colors p-0.5 rounded hover:bg-n-alpha-2"
        :title="$t('CHAT_LIST.SEARCH.CLEAR')"
        @click="clear"
      >
        <span class="i-lucide-x size-4 block text-n-slate-10" />
      </button>
      <kbd
        v-else-if="!isFocused"
        class="hidden sm:inline-flex items-center justify-center px-1.5 py-0.5 text-[10px] font-medium text-n-slate-10 bg-n-alpha-2 dark:bg-n-solid-3 rounded border border-n-weak select-none pointer-events-none"
      >
        /
      </kbd>
    </div>
  </div>
</template>
