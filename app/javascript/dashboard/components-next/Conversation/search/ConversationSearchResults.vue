<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getInboxIconByType } from 'dashboard/helper/inbox';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  query: {
    type: String,
    default: '',
  },
  isFetching: {
    type: Boolean,
    default: false,
  },
  activeConversationId: {
    type: [String, Number],
    default: null,
  },
  activeMessageId: {
    type: [String, Number],
    default: null,
  },
  isOnExpandedLayout: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'selectConversation',
  'selectMessage',
  'selectContact',
  'viewContact',
]);

const { t } = useI18n();
const { getPlainText } = useMessageFormatter();

const selectedTab = ref('all');

const contactRecords = useMapGetter('conversationSearch/getContactRecords');
const conversationRecords = useMapGetter(
  'conversationSearch/getConversationRecords'
);
const messageRecords = useMapGetter('conversationSearch/getMessageRecords');
const articleRecords = useMapGetter('conversationSearch/getArticleRecords');
const uiFlags = useMapGetter('conversationSearch/getUIFlags');

const contacts = computed(() =>
  useCamelCase(contactRecords.value || [], { deep: true })
);
const conversations = computed(() =>
  useCamelCase(conversationRecords.value || [], { deep: true })
);
const messages = computed(() =>
  useCamelCase(messageRecords.value || [], { deep: true })
);
const articles = computed(() =>
  useCamelCase(articleRecords.value || [], { deep: true })
);

const totalCount = computed(() => {
  return (
    contacts.value.length +
    conversations.value.length +
    messages.value.length +
    articles.value.length
  );
});

const tabs = computed(() => {
  const list = [
    {
      key: 'all',
      label: t('CHAT_LIST.SEARCH.TABS.ALL'),
      count: totalCount.value,
    },
    {
      key: 'conversations',
      label: t('CHAT_LIST.SEARCH.TABS.CHATS'),
      count: conversations.value.length,
    },
    {
      key: 'messages',
      label: t('CHAT_LIST.SEARCH.TABS.MESSAGES'),
      count: messages.value.length,
    },
    {
      key: 'contacts',
      label: t('CHAT_LIST.SEARCH.TABS.CONTACTS'),
      count: contacts.value.length,
    },
  ];
  if (articles.value.length > 0) {
    list.push({
      key: 'articles',
      label: t('SEARCH.TABS.ARTICLES'),
      count: articles.value.length,
    });
  }
  return list;
});

const isQueryTooShort = computed(() => {
  const trimmed = props.query?.trim() || '';
  return trimmed.length < 2 && !trimmed.match(/^[0-9]+$/);
});

const escapeHtml = text => {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = String(text);
  return div.innerHTML;
};

const highlight = (text, term) => {
  if (!text) return '';
  const escaped = escapeHtml(text);
  if (!term || !term.trim()) return escaped;
  const escapedTerm = escapeHtml(term.trim()).replace(
    /[.*+?^${}()|[\]\\]/g,
    '\\$&'
  );
  return escaped.replace(
    new RegExp(`(${escapedTerm})`, 'ig'),
    '<mark class="bg-n-brand/20 text-n-brand font-semibold rounded-xs px-0.5">$1</mark>'
  );
};

const formatTime = timestamp => {
  if (!timestamp) return '';
  try {
    return shortTimestamp(dynamicTime(timestamp));
  } catch (e) {
    return '';
  }
};

const getConversationSnippet = conversation => {
  if (conversation.mailSubject) {
    return conversation.mailSubject;
  }
  if (conversation.message?.content) {
    return getPlainText(conversation.message.content);
  }
  return '';
};

const getMessageSnippet = message => {
  if (message.content) {
    return getPlainText(message.content);
  }
  if (message.contentAttributes?.email?.subject) {
    return message.contentAttributes.email.subject;
  }
  const audio = message.attachments?.find(att => att.fileType === 'audio');
  if (audio?.transcribedText) {
    return audio.transcribedText;
  }
  if (message.attachments?.length) {
    return `[${message.attachments.length} attachment(s)]`;
  }
  return '';
};

const getChannelIcon = inbox => {
  if (!inbox) return null;
  const channelType = inbox.channelType || inbox.channel_type;
  const medium = inbox.medium;
  return getInboxIconByType(channelType, medium, 'fill');
};

const isActiveConversation = id => {
  return Number(props.activeConversationId) === Number(id);
};

const isActiveMessage = message => {
  return (
    Number(props.activeConversationId) === Number(message.conversationId) &&
    Number(props.activeMessageId) === Number(message.id)
  );
};

const showConversations = computed(() => {
  return (
    (selectedTab.value === 'all' || selectedTab.value === 'conversations') &&
    conversations.value.length > 0
  );
});

const showMessages = computed(() => {
  return (
    (selectedTab.value === 'all' || selectedTab.value === 'messages') &&
    messages.value.length > 0
  );
});

const showContacts = computed(() => {
  return (
    (selectedTab.value === 'all' || selectedTab.value === 'contacts') &&
    contacts.value.length > 0
  );
});
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 bg-n-surface-1">
    <!-- Filter Pills (All, Chats, Messages, Contacts) -->
    <div
      class="flex items-center gap-1.5 px-3 py-1.5 overflow-x-auto border-b border-n-weak/50 shrink-0 no-scrollbar"
    >
      <button
        v-for="tab in tabs"
        :key="tab.key"
        type="button"
        class="flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium transition-all shrink-0 cursor-pointer"
        :class="[
          selectedTab === tab.key
            ? 'bg-n-brand/10 text-n-brand font-semibold dark:bg-n-brand/20'
            : 'bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-3',
        ]"
        @click="selectedTab = tab.key"
      >
        <span>{{ tab.label }}</span>
        <span
          v-if="tab.count > 0"
          class="px-1.5 py-0.2 rounded-full text-[10px]"
          :class="
            selectedTab === tab.key
              ? 'bg-n-brand/20 text-n-brand'
              : 'bg-n-slate-3 text-n-slate-11 dark:bg-n-solid-3 dark:text-n-slate-12'
          "
        >
          {{ tab.count }}
        </span>
      </button>
    </div>

    <!-- Query Too Short -->
    <div
      v-if="isQueryTooShort"
      class="flex flex-col items-center justify-center p-8 text-center"
    >
      <span class="i-lucide-search size-8 text-n-slate-9 mb-2" />
      <p class="text-xs text-n-slate-11">
        {{ $t('CHAT_LIST.SEARCH.MIN_CHARACTERS') }}
      </p>
    </div>

    <!-- Loading State -->
    <div
      v-else-if="isFetching && totalCount === 0"
      class="flex flex-col items-center justify-center p-8 gap-2"
    >
      <Spinner :size="24" class="text-n-brand" />
      <span class="text-xs text-n-slate-11"
        >{{ $t('SEARCH.SEARCHING_DATA') }}...</span
      >
    </div>

    <!-- Empty Results -->
    <div
      v-else-if="!isFetching && uiFlags.isSearchCompleted && totalCount === 0"
      class="flex flex-col items-center justify-center p-8 text-center"
    >
      <span class="i-lucide-search-x size-8 text-n-slate-9 mb-2" />
      <p class="text-sm font-medium text-n-slate-12 mb-1">
        {{ $t('CHAT_LIST.SEARCH.NO_RESULTS', { query }) }}
      </p>
      <p class="text-xs text-n-slate-10">
        {{ $t('SEARCH.EMPTY_STATE_DEFAULT') }}
      </p>
    </div>

    <!-- Results List -->
    <div
      v-else
      class="flex-1 min-h-0 overflow-y-auto divide-y divide-n-weak/40"
    >
      <!-- Chats / Conversations -->
      <section v-if="showConversations">
        <div
          v-if="selectedTab === 'all'"
          class="sticky top-0 z-10 px-3 py-1.5 bg-n-surface-1/95 backdrop-blur-sm border-b border-n-weak/40 flex items-center justify-between"
        >
          <span
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-10"
          >
            {{ $t('CHAT_LIST.SEARCH.TABS.CHATS') }}
          </span>
          <span class="text-xs text-n-slate-10">
            {{ conversations.length }}
          </span>
        </div>
        <div class="divide-y divide-n-weak/30">
          <div
            v-for="conversation in conversations"
            :key="`conv-${conversation.id}`"
            role="button"
            tabindex="0"
            class="flex items-start gap-3 px-3 py-3 cursor-pointer transition-colors duration-150 hover:bg-n-alpha-1 dark:hover:bg-n-solid-2"
            :class="{
              'bg-n-alpha-2 dark:bg-n-solid-2': isActiveConversation(
                conversation.id
              ),
            }"
            @click="emit('selectConversation', conversation, $event)"
          >
            <Avatar
              :name="conversation.contact?.name || String(conversation.id)"
              :src="conversation.contact?.thumbnail"
              :size="36"
              class="shrink-0 mt-0.5"
            />
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between gap-1 mb-1">
                <h4
                  v-dompurify-html="
                    highlight(
                      conversation.contact?.name || `#${conversation.id}`,
                      query
                    )
                  "
                  class="text-sm font-semibold text-n-slate-12 truncate m-0"
                />
                <span class="text-xs text-n-slate-10 shrink-0">
                  {{ formatTime(conversation.createdAt) }}
                </span>
              </div>
              <div
                class="flex items-center gap-1.5 mb-1 text-xs text-n-slate-11"
              >
                <span class="font-medium">#{{ conversation.id }}</span>
                <template v-if="conversation.inbox?.name">
                  <span>·</span>
                  <span
                    v-if="getChannelIcon(conversation.inbox)"
                    :class="[
                      getChannelIcon(conversation.inbox),
                      'size-3.5 shrink-0 text-n-slate-10',
                    ]"
                  />
                  <span class="truncate">{{ conversation.inbox.name }}</span>
                </template>
              </div>
              <p
                v-if="getConversationSnippet(conversation)"
                v-dompurify-html="
                  highlight(getConversationSnippet(conversation), query)
                "
                class="text-xs text-n-slate-11 line-clamp-2 m-0"
              />
            </div>
          </div>
        </div>
      </section>

      <!-- Messages -->
      <section v-if="showMessages">
        <div
          v-if="selectedTab === 'all'"
          class="sticky top-0 z-10 px-3 py-1.5 bg-n-surface-1/95 backdrop-blur-sm border-b border-n-weak/40 flex items-center justify-between"
        >
          <span
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-10"
          >
            {{ $t('CHAT_LIST.SEARCH.TABS.MESSAGES') }}
          </span>
          <span class="text-xs text-n-slate-10">
            {{ messages.length }}
          </span>
        </div>
        <div class="divide-y divide-n-weak/30">
          <div
            v-for="message in messages"
            :key="`msg-${message.id}`"
            role="button"
            tabindex="0"
            class="flex items-start gap-3 px-3 py-3 cursor-pointer transition-colors duration-150 hover:bg-n-alpha-1 dark:hover:bg-n-solid-2"
            :class="{
              'bg-n-alpha-2 dark:bg-n-solid-2': isActiveMessage(message),
            }"
            @click="emit('selectMessage', message, $event)"
          >
            <Avatar
              :name="message.sender?.name || $t('SEARCH.BOT_LABEL')"
              :src="message.sender?.thumbnail"
              :size="36"
              class="shrink-0 mt-0.5"
            />
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between gap-1 mb-1">
                <span class="text-sm font-semibold text-n-slate-12 truncate">
                  {{ message.sender?.name || $t('SEARCH.BOT_LABEL') }}
                </span>
                <span class="text-xs text-n-slate-10 shrink-0">
                  {{ formatTime(message.createdAt) }}
                </span>
              </div>
              <div
                class="flex items-center gap-1.5 mb-1 text-xs text-n-slate-11"
              >
                <span class="font-medium">#{{ message.conversationId }}</span>
                <span
                  v-if="message.private"
                  class="inline-flex items-center gap-1 px-1.5 py-0.2 rounded bg-n-amber-3 text-n-amber-11 text-[10px]"
                >
                  <span class="i-lucide-lock size-2.5" />
                  {{ $t('SEARCH.PRIVATE') }}
                </span>
              </div>
              <p
                v-dompurify-html="
                  highlight(getMessageSnippet(message), query)
                "
                class="text-xs text-n-slate-11 line-clamp-2 m-0"
              />
            </div>
          </div>
        </div>
      </section>

      <!-- Contacts -->
      <section v-if="showContacts">
        <div
          v-if="selectedTab === 'all'"
          class="sticky top-0 z-10 px-3 py-1.5 bg-n-surface-1/95 backdrop-blur-sm border-b border-n-weak/40 flex items-center justify-between"
        >
          <span
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-10"
          >
            {{ $t('CHAT_LIST.SEARCH.TABS.CONTACTS') }}
          </span>
          <span class="text-xs text-n-slate-10">
            {{ contacts.length }}
          </span>
        </div>
        <div class="divide-y divide-n-weak/30">
          <div
            v-for="contact in contacts"
            :key="`contact-${contact.id}`"
            role="button"
            tabindex="0"
            class="flex items-center gap-3 px-3 py-3 cursor-pointer transition-colors duration-150 hover:bg-n-alpha-1 dark:hover:bg-n-solid-2 group"
            @click="emit('selectContact', contact, $event)"
          >
            <Avatar
              :name="contact.name || contact.email || 'Contact'"
              :src="contact.thumbnail"
              :size="36"
              class="shrink-0"
            />
            <div class="flex-1 min-w-0">
              <h4
                v-dompurify-html="
                  highlight(
                    contact.name || contact.email || `Contact #${contact.id}`,
                    query
                  )
                "
                class="text-sm font-semibold text-n-slate-12 truncate m-0 mb-0.5"
              />
              <div
                class="flex items-center gap-2 text-xs text-n-slate-11 truncate"
              >
                <span v-if="contact.email" class="truncate">{{
                  contact.email
                }}</span>
                <span v-if="contact.email && contact.phoneNumber">·</span>
                <span v-if="contact.phoneNumber" class="truncate">{{
                  contact.phoneNumber
                }}</span>
              </div>
            </div>
            <!-- Quick View Profile Action -->
            <button
              type="button"
              class="p-1 rounded text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 shrink-0 transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100"
              :title="$t('CHAT_LIST.SEARCH.VIEW_CONTACT')"
              @click.stop="emit('viewContact', contact, $event)"
            >
              <span class="i-lucide-external-link size-4 block" />
            </button>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
