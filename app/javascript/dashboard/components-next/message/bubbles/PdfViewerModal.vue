<script setup>
import { ref } from 'vue';
import NextButton from 'next/button/Button.vue';
import TeleportWithDirection from 'next/TeleportWithDirection.vue';
import { downloadFile } from '@chatwoot/utils';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

const props = defineProps({
  url: { type: String, required: true },
  fileName: { type: String, default: '' },
  fileSize: { type: String, default: '' },
  numPages: { type: [Number, String], default: null },
});

const show = defineModel('show', { type: Boolean, default: false });
const emit = defineEmits(['close']);
const isDownloading = ref(false);

const onClose = () => {
  show.value = false;
  emit('close');
};

const onDownload = async () => {
  try {
    isDownloading.value = true;
    await downloadFile({ url: props.url, type: 'file', extension: 'pdf' });
  } catch (e) {
    window.open(props.url, '_blank');
  } finally {
    isDownloading.value = false;
  }
};

useKeyboardEvents({
  Escape: { action: onClose },
});
</script>

<template>
  <TeleportWithDirection to="body">
    <woot-modal
      v-model:show="show"
      full-width
      :show-close-button="false"
      :on-close="onClose"
    >
      <div
        class="bg-n-background flex flex-col h-[inherit] w-[inherit] overflow-hidden select-none"
        @click="onClose"
      >
        <header
          class="z-10 flex items-center justify-between w-full h-16 px-6 py-2 bg-n-background border-b border-n-weak shrink-0"
          @click.stop
        >
          <!-- Document info -->
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="w-8 h-9 rounded bg-[#EA4335] text-white flex flex-col items-center justify-center shrink-0 shadow-sm relative overflow-hidden"
            >
              <div
                class="absolute top-0 right-0 w-2 h-2 bg-black/20 rounded-bl-[2px]"
              />
              <span class="text-[8.5px] font-black tracking-wider mt-0.5"
                >PDF</span
              >
              <div class="w-3.5 h-0.5 bg-white/40 rounded-full mt-0.5" />
            </div>
            <div class="flex flex-col min-w-0">
              <span
                class="text-sm font-semibold text-n-slate-12 truncate max-w-lg"
                :title="fileName"
              >
                {{ fileName }}
              </span>
              <span class="text-xs text-n-slate-11">
                <span v-if="numPages">
                  {{ numPages }} {{ numPages === 1 ? 'page' : 'pages' }} •
                </span>
                <span v-if="fileSize">{{ fileSize }} • </span>
                PDF Document
              </span>
            </div>
          </div>

          <!-- Actions -->
          <div class="flex items-center gap-1 sm:gap-2">
            <!-- React Action (Emoji reaction) -->
            <NextButton
              sm
              ghost
              slate
              icon="i-lucide-smile-plus"
              :title="$t('CONVERSATION.REACT')"
            />
            <!-- Dummy Star Action -->
            <NextButton
              sm
              ghost
              slate
              icon="i-lucide-star"
              :title="$t('CONVERSATION.STAR')"
            />
            <!-- Dummy Pin Action -->
            <NextButton
              sm
              ghost
              slate
              icon="i-lucide-pin"
              :title="$t('CONVERSATION.PIN')"
            />
            <!-- Dummy Forward Action -->
            <NextButton
              sm
              ghost
              slate
              icon="i-lucide-forward"
              :title="$t('CONVERSATION.FORWARD')"
            />
            <!-- Direct Download Action (Icon only) -->
            <NextButton
              sm
              ghost
              slate
              icon="i-lucide-download"
              :is-loading="isDownloading"
              :disabled="isDownloading"
              :title="$t('CONVERSATION.DOWNLOAD')"
              @click="onDownload"
            />
            <!-- Go back to message in conversation -->
            <NextButton
              sm
              ghost
              slate
              icon="i-lucide-message-square"
              :title="$t('CONVERSATION.GO_TO_MESSAGE')"
              @click="onClose"
            />
            <!-- Close Modal Action -->
            <NextButton
              sm
              ghost
              slate
              icon="i-lucide-x"
              class="ml-1"
              :title="$t('MODAL.CLOSE') || 'Close'"
              @click="onClose"
            />
          </div>
        </header>

        <main
          class="flex-1 w-full h-full relative overflow-hidden bg-n-slate-2 dark:bg-n-slate-1"
          @click.stop
        >
          <iframe
            :src="`${url}#toolbar=1&navpanes=1`"
            class="w-full h-full border-0"
            title="PDF Preview"
          />
        </main>
      </div>
    </woot-modal>
  </TeleportWithDirection>
</template>
