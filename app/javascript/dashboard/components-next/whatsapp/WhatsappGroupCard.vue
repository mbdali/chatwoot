<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import CreateWhatsappGroupModal from './CreateWhatsappGroupModal.vue';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: Number,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const showModal = ref(false);

const currentChat = computed(() => store.getters.getSelectedChat);
const inbox = computed(() => store.getters['inboxes/getInbox'](props.inboxId));

const isWhatsappChannel = computed(() => {
  return inbox.value?.channel_type === 'Channel::Whatsapp';
});

const isGroupConversation = computed(() => {
  return (
    currentChat.value?.additional_attributes?.is_group === true ||
    currentChat.value?.meta?.sender?.additional_attributes?.is_group === true
  );
});

const inviteLink = computed(() => {
  return (
    currentChat.value?.additional_attributes?.invite_link ||
    currentChat.value?.meta?.sender?.additional_attributes?.invite_link ||
    ''
  );
});

const contactName = computed(() => {
  return currentChat.value?.meta?.sender?.name || '';
});

const handleCopyLink = async () => {
  if (!inviteLink.value) return;
  await copyTextToClipboard(inviteLink.value);
  useAlert(
    t('WHATSAPP_GROUPS.LINK_COPIED', 'Invite link copied to clipboard!')
  );
};
</script>

<template>
  <div
    v-if="isWhatsappChannel"
    class="px-4 py-3 border-b border-n-slate-4 dark:border-n-solid-3"
  >
    <!-- Active Group View -->
    <div v-if="isGroupConversation" class="flex flex-col gap-2.5">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <span
            class="inline-flex items-center justify-center w-6 h-6 rounded-md bg-green-100 dark:bg-green-950 text-green-700 dark:text-green-300"
          >
            <span class="i-lucide-users w-4 h-4" />
          </span>
          <span
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-11"
          >
            {{ t('WHATSAPP_GROUPS.GROUP_INFO_TITLE', 'WhatsApp Group') }}
          </span>
        </div>
        <span
          class="text-[11px] font-medium px-2 py-0.5 rounded-full bg-green-100 dark:bg-green-950 text-green-700 dark:text-green-300"
        >
          {{ t('WHATSAPP_GROUPS.ACTIVE_BADGE', 'Multi-party') }}
        </span>
      </div>

      <div v-if="inviteLink" class="flex items-center gap-2 mt-1">
        <input
          type="text"
          readonly
          :value="inviteLink"
          class="w-full text-xs font-mono px-2.5 py-1.5 rounded-lg bg-n-slate-2 dark:bg-n-solid-2 text-n-slate-11 border border-n-slate-4 dark:border-n-solid-4 select-all"
        />
        <Button
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-copy"
          :label="t('WHATSAPP_GROUPS.COPY', 'Copy')"
          @click="handleCopyLink"
        />
      </div>
    </div>

    <!-- 1-on-1 Contact View: Create Group CTA -->
    <div v-else class="flex flex-col gap-2">
      <div class="flex items-center justify-between">
        <span
          class="text-xs font-semibold uppercase tracking-wider text-n-slate-11"
        >
          {{ t('WHATSAPP_GROUPS.GROUP_SECTION_TITLE', 'WhatsApp Groups') }}
        </span>
      </div>
      <p class="text-xs text-n-slate-11">
        {{
          t(
            'WHATSAPP_GROUPS.GROUP_SECTION_DESC',
            'Create an invite-only WhatsApp group for multi-party support with this contact.'
          )
        }}
      </p>
      <Button
        variant="faded"
        color="blue"
        size="sm"
        icon="i-lucide-users-plus"
        :label="t('WHATSAPP_GROUPS.CREATE_GROUP', 'Create WhatsApp Group')"
        class="w-full justify-center mt-1"
        @click="showModal = true"
      />
    </div>

    <!-- Group Creation Modal -->
    <CreateWhatsappGroupModal
      v-if="showModal"
      v-model:show="showModal"
      :inbox-id="inboxId"
      :conversation-id="conversationId"
      :contact-name="contactName"
      @close="showModal = false"
    />
  </div>
  <div v-else />
</template>
