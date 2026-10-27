<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  reactions: {
    type: Array,
    default: () => [],
  },
  currentUserId: {
    type: Number,
    default: null,
  },
  canReact: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['toggle']);

const { t } = useI18n();

const groupedReactions = computed(() => {
  if (!props.reactions || !props.reactions.length) return [];

  const groups = {};
  props.reactions.forEach(r => {
    const emoji = r.emoji;
    if (!emoji) return;

    if (!groups[emoji]) {
      groups[emoji] = {
        emoji,
        count: 0,
        users: [],
        hasReacted: false,
      };
    }

    groups[emoji].count += 1;

    const isCurrentUser =
      r.actor_type === 'User' &&
      Number(r.actor_id) === Number(props.currentUserId);

    if (isCurrentUser) {
      groups[emoji].hasReacted = true;
    }

    const displayName = isCurrentUser
      ? t('CONVERSATION.REACTIONS.YOU')
      : r.actor_name || r.actor_type || 'User';

    groups[emoji].users.push(displayName);
  });

  return Object.values(groups);
});

const getTooltipContent = group => {
  return group.users.join(', ');
};

const onReactionClick = emoji => {
  if (!props.canReact) return;
  emit('toggle', emoji);
};
</script>

<template>
  <div
    v-if="groupedReactions.length"
    class="flex flex-wrap items-center gap-1 mt-1 z-10"
  >
    <button
      v-for="group in groupedReactions"
      :key="group.emoji"
      v-tooltip.top="getTooltipContent(group)"
      type="button"
      class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full border text-xs shadow-xs transition-all duration-150 cursor-pointer active:scale-95"
      :class="[
        group.hasReacted
          ? 'bg-n-brand/10 border-n-brand/40 text-n-brand font-medium'
          : 'bg-n-solid-1 dark:bg-n-solid-2 border-n-weak text-n-slate-12 hover:border-n-strong',
      ]"
      @click.stop="onReactionClick(group.emoji)"
    >
      <span class="text-xs leading-none select-none">{{ group.emoji }}</span>
      <span
        v-if="group.count > 1"
        class="text-[11px] leading-none text-n-slate-11 font-medium select-none"
      >
        {{ group.count }}
      </span>
    </button>
  </div>
  <div v-else />
</template>
