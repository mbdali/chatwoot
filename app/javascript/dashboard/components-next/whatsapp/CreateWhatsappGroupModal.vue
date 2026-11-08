<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import Modal from 'dashboard/components/Modal.vue';
import ModalHeader from 'dashboard/components/ModalHeader.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import WhatsappGroupsAPI from 'dashboard/api/channel/whatsapp/whatsappGroupsAPI';

const props = defineProps({
  inboxId: {
    type: [Number, String],
    required: true,
  },
  conversationId: {
    type: [Number, String],
    default: null,
  },
  contactName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'created']);
const show = defineModel('show', { type: Boolean, default: false });

const { t } = useI18n();
const router = useRouter();

const subject = ref('');
const description = ref('');
const autoInvite = ref(true);
const isSubmitting = ref(false);
const createdGroup = ref(null);

const isValid = computed(() => subject.value.trim().length > 0);

const resetForm = () => {
  subject.value = '';
  description.value = '';
  autoInvite.value = true;
  isSubmitting.value = false;
  createdGroup.value = null;
};

const handleClose = () => {
  show.value = false;
  emit('close');
  resetForm();
};

const handleSubmit = async () => {
  if (!isValid.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const data = await WhatsappGroupsAPI.create({
      inboxId: props.inboxId,
      subject: subject.value.trim(),
      description: description.value.trim(),
      conversationId: props.conversationId,
      autoInvite: autoInvite.value && !!props.conversationId,
    });

    createdGroup.value = data;
    emit('created', data);
    useAlert(
      t(
        'WHATSAPP_GROUPS.GROUP_CREATED_SUCCESS',
        'WhatsApp group created successfully!'
      )
    );
  } catch (error) {
    const errorMsg =
      error?.response?.data?.error ||
      error.message ||
      t('WHATSAPP_GROUPS.CREATE_FAILED', 'Failed to create group');
    useAlert(errorMsg);
  } finally {
    isSubmitting.value = false;
  }
};

const handleCopyLink = async () => {
  if (!createdGroup.value?.invite_link) return;
  await copyTextToClipboard(createdGroup.value.invite_link);
  useAlert(
    t('WHATSAPP_GROUPS.LINK_COPIED', 'Invite link copied to clipboard!')
  );
};

const handleNavigateToGroup = () => {
  if (!createdGroup.value?.conversation_id) return;
  const targetConvId = createdGroup.value.conversation_id;
  handleClose();
  router.push({
    name: 'inbox_conversation',
    params: {
      conversation_id: targetConvId,
    },
  });
};
</script>

<template>
  <Modal v-model:show="show" :on-close="handleClose">
    <div
      class="flex flex-col w-full max-w-lg bg-n-alpha-3 dark:bg-n-solid-2 rounded-2xl overflow-hidden shadow-2xl"
    >
      <ModalHeader
        :header-title="
          createdGroup
            ? t('WHATSAPP_GROUPS.GROUP_CREATED_TITLE', 'Group Ready!')
            : t('WHATSAPP_GROUPS.CREATE_GROUP_TITLE', 'Create WhatsApp Group')
        "
        :header-content="
          createdGroup
            ? t(
                'WHATSAPP_GROUPS.GROUP_READY_DESC',
                'Your WhatsApp group is created. Share the invite link with participants.'
              )
            : t(
                'WHATSAPP_GROUPS.CREATE_GROUP_DESC',
                'Create a WhatsApp group for multi-party support on your verified WhatsApp Cloud number.'
              )
        "
      />

      <!-- Success State -->
      <div v-if="createdGroup" class="p-8 flex flex-col gap-5">
        <div
          class="flex flex-col gap-2 p-4 rounded-xl bg-n-slate-3 dark:bg-n-solid-3 border border-n-slate-4 dark:border-n-solid-4"
        >
          <span
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-11"
          >
            {{ t('WHATSAPP_GROUPS.INVITE_LINK_LABEL', 'Group Invite Link') }}
          </span>
          <div class="flex items-center gap-2">
            <input
              type="text"
              readonly
              :value="
                createdGroup.invite_link ||
                t('WHATSAPP_GROUPS.LINK_PENDING', 'Generating invite link...')
              "
              class="w-full text-xs font-mono px-3 py-2 rounded-lg bg-n-slate-1 dark:bg-n-solid-1 text-n-slate-12 border border-n-slate-5 dark:border-n-solid-5 select-all"
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
          <p
            v-if="createdGroup.invited"
            class="text-xs text-green-600 dark:text-green-400 mt-1 flex items-center gap-1"
          >
            <span class="i-lucide-check-circle inline-block w-3.5 h-3.5" />
            {{
              t(
                'WHATSAPP_GROUPS.INVITE_SENT_NOTICE',
                'Invite link was sent to customer in conversation.'
              )
            }}
          </p>
        </div>

        <div
          class="flex items-center justify-end gap-3 pt-3 border-t border-n-slate-4 dark:border-n-solid-4"
        >
          <Button
            variant="ghost"
            color="slate"
            :label="t('WHATSAPP_GROUPS.CLOSE', 'Close')"
            @click="handleClose"
          />
          <Button
            v-if="createdGroup.conversation_id"
            color="blue"
            icon="i-lucide-arrow-right"
            :label="
              t(
                'WHATSAPP_GROUPS.OPEN_GROUP_CONVERSATION',
                'Open Group Conversation'
              )
            "
            @click="handleNavigateToGroup"
          />
        </div>
      </div>

      <!-- Creation Form State -->
      <form
        v-else
        class="p-8 flex flex-col gap-5"
        @submit.prevent="handleSubmit"
      >
        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('WHATSAPP_GROUPS.SUBJECT_LABEL', 'Group Subject') }}
            <!-- eslint-disable-next-line @intlify/vue-i18n/no-raw-text -->
            <span class="text-red-500" aria-hidden="true">*</span>
          </label>
          <Input
            v-model="subject"
            :placeholder="
              t(
                'WHATSAPP_GROUPS.SUBJECT_PLACEHOLDER',
                'e.g. VIP Client Project Room'
              )
            "
            autofocus
            maxlength="100"
          />
        </div>

        <div class="flex flex-col gap-1.5">
          <label class="text-sm font-medium text-n-slate-12">
            {{
              t(
                'WHATSAPP_GROUPS.DESCRIPTION_LABEL',
                'Group Description (Optional)'
              )
            }}
          </label>
          <Input
            v-model="description"
            :placeholder="
              t(
                'WHATSAPP_GROUPS.DESCRIPTION_PLACEHOLDER',
                'Brief purpose of the group'
              )
            "
            maxlength="255"
          />
        </div>

        <div
          v-if="conversationId"
          class="flex items-center gap-3 p-3 rounded-xl bg-n-slate-2 dark:bg-n-solid-3 border border-n-slate-4 dark:border-n-solid-4"
        >
          <input
            id="auto-invite-checkbox"
            v-model="autoInvite"
            type="checkbox"
            class="rounded border-n-slate-5 text-blue-600 focus:ring-blue-500 cursor-pointer w-4 h-4"
          />
          <label
            for="auto-invite-checkbox"
            class="text-xs text-n-slate-11 cursor-pointer select-none"
          >
            {{
              t(
                'WHATSAPP_GROUPS.AUTO_INVITE_LABEL',
                'Automatically send invite link in the current conversation'
              )
            }}
            <span v-if="contactName" class="font-semibold text-n-slate-12">
              {{ `(${contactName})` }}
            </span>
          </label>
        </div>

        <div
          class="flex items-center justify-end gap-3 pt-4 border-t border-n-slate-4 dark:border-n-solid-4"
        >
          <Button
            variant="ghost"
            color="slate"
            :label="t('WHATSAPP_GROUPS.CANCEL', 'Cancel')"
            @click="handleClose"
          />
          <Button
            type="submit"
            color="blue"
            :disabled="!isValid || isSubmitting"
            :is-loading="isSubmitting"
            :label="
              isSubmitting
                ? t('WHATSAPP_GROUPS.CREATING_BUTTON', 'Creating Group...')
                : t('WHATSAPP_GROUPS.CREATE_BUTTON', 'Create Group')
            "
          />
        </div>
      </form>
    </div>
  </Modal>
</template>
