<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute } from 'vue-router';
import subDays from 'date-fns/subDays';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import BarChart from 'shared/components/charts/BarChart.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { useAlert } from 'dashboard/composables';
import { fetchMessageReports } from 'dashboard/api/raqmi_connect/messageReports';

const { t } = useI18n();
const store = useStore();
const route = useRoute();

const accountId = computed(() => route.params.accountId);

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const selectedInbox = ref('');
const selectedInterval = ref('day');
const outgoingGroupBy = ref('status');
const isLoading = ref(false);

const reportData = ref({
  incoming: {
    total: 0,
    previous_total: 0,
    trend: 0,
    chart_data: { categories: [], series: [] },
  },
  outgoing: {
    total: 0,
    previous_total: 0,
    trend: 0,
    delivered_count: 0,
    delivery_rate: 0,
    previous_delivery_rate: 0,
    delivery_rate_trend: 0,
    failed_count: 0,
    error_rate: 0,
    previous_error_rate: 0,
    error_rate_trend: 0,
    chart_data: { categories: [], series: [] },
  },
});

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);

const inboxOptions = computed(() => [
  { value: '', label: t('MESSAGES_REPORT.FILTER_ALL_INBOXES') },
  ...inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  })),
]);

const intervalOptions = computed(() => [
  { value: 'day', label: t('MESSAGES_REPORT.INTERVAL.DAY') },
  { value: 'week', label: t('MESSAGES_REPORT.INTERVAL.WEEK') },
  { value: 'month', label: t('MESSAGES_REPORT.INTERVAL.MONTH') },
]);

const PALETTE_CLASSES = [
  'bg-n-blue-9',
  'bg-n-teal-9',
  'bg-n-amber-9',
  'bg-n-ruby-9',
  'bg-n-iris-9',
  'bg-n-grass-9',
  'bg-n-plum-9',
  'bg-n-cyan-9',
];

const STATUS_COLOR_CLASSES = {
  status_read: 'bg-emerald-600',
  status_delivered: 'bg-teal-600',
  status_sent: 'bg-sky-600',
  status_failed: 'bg-rose-600',
};

const getSeriesColorClass = (item, idx) => {
  if (STATUS_COLOR_CLASSES[item.id]) {
    return STATUS_COLOR_CLASSES[item.id];
  }
  return PALETTE_CLASSES[idx % PALETTE_CLASSES.length];
};

const formatNumber = val => {
  if (val === null || val === undefined) return '0';
  return new Intl.NumberFormat().format(val);
};

const formatPercent = val => {
  if (val === null || val === undefined) return '0%';
  return `${Number(val).toFixed(1)}%`;
};

const formatTrend = val => {
  if (!val || val === 0) return '0%';
  const prefix = val > 0 ? '+' : '';
  return `${prefix}${Number(val).toFixed(1)}%`;
};

const loadReport = async () => {
  if (!accountId.value) return;

  const since = getUnixStartOfDay(customDateRange.value[0]);
  const until = getUnixEndOfDay(customDateRange.value[1]);

  isLoading.value = true;
  try {
    const params = {
      since,
      until,
      group_by: selectedInterval.value,
      outgoing_group_by: outgoingGroupBy.value,
    };
    if (selectedInbox.value) {
      params.inbox_id = selectedInbox.value;
    }

    const response = await fetchMessageReports(accountId.value, params);
    if (response?.data) {
      reportData.value = response.data;
    }
  } catch (error) {
    useAlert(t('REPORT.DATA_FETCHING_FAILED'));
  } finally {
    isLoading.value = false;
  }
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  loadReport();
};

const setOutgoingGroupBy = mode => {
  if (outgoingGroupBy.value === mode) return;
  outgoingGroupBy.value = mode;
  loadReport();
};

watch(selectedInbox, () => {
  loadReport();
});

watch(selectedInterval, () => {
  loadReport();
});

onMounted(() => {
  if (!inboxes.value.length) {
    store.dispatch('inboxes/get');
  }
  loadReport();
});
</script>

<template>
  <div class="flex flex-col gap-6 pb-10">
    <section class="flex flex-col gap-1 pt-6 pb-5">
      <div class="flex justify-between w-full gap-5">
        <div class="flex flex-col gap-2">
          <div class="flex flex-col gap-3 items-start">
            <span
              class="text-heading-1 text-n-slate-12 min-h-10 flex items-center gap-2"
            >
              {{ t('MESSAGES_REPORT.HEADER') }}
            </span>
            <p class="text-n-slate-11 mb-0 text-body-main">
              {{ t('MESSAGES_REPORT.DESCRIPTION') }}
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- Filter Bar -->
    <div
      class="flex flex-wrap items-center justify-between gap-3 p-4 bg-n-solid-2 border border-n-weak rounded-xl"
    >
      <div class="flex flex-wrap items-center gap-3">
        <WootDatePicker
          v-model:date-range="customDateRange"
          v-model:range-type="selectedDateRange"
          @date-range-changed="onDateRangeChange"
        />

        <div class="flex items-center gap-2">
          <Select
            v-model="selectedInbox"
            :options="inboxOptions"
            :aria-label="t('MESSAGES_REPORT.FILTER_ALL_INBOXES')"
            class="min-w-44"
          />
        </div>
      </div>

      <div class="flex items-center gap-2">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('MESSAGES_REPORT.INTERVAL.LABEL') }}
        </span>
        <Select
          v-model="selectedInterval"
          :options="intervalOptions"
          :aria-label="t('MESSAGES_REPORT.INTERVAL.LABEL')"
          class="min-w-28"
        />
      </div>
    </div>

    <!-- Loading State -->
    <div
      v-if="
        isLoading && !reportData.incoming.total && !reportData.outgoing.total
      "
      class="flex justify-center py-20"
    >
      <Spinner />
    </div>

    <div v-else class="flex flex-col gap-6">
      <!-- Section 1: Incoming Messages -->
      <div
        class="p-6 bg-n-solid-2 border border-n-weak rounded-xl flex flex-col gap-5"
      >
        <div
          class="flex items-center justify-between border-b border-n-weak pb-4"
        >
          <div class="flex items-center gap-2">
            <span class="i-lucide-arrow-down-left size-5 text-sky-600" />
            <h3 class="text-base font-semibold text-n-slate-12 mb-0">
              {{ t('MESSAGES_REPORT.INCOMING_SECTION.TITLE') }}
            </h3>
          </div>
        </div>

        <!-- Incoming Summary Metric Tile -->
        <div
          class="flex items-center gap-4 p-4 rounded-lg bg-n-surface-1 border border-n-weak w-fit min-w-64"
        >
          <div class="flex flex-col gap-1">
            <span class="text-xs font-medium text-n-slate-11">
              {{ t('MESSAGES_REPORT.INCOMING_SECTION.TOTAL') }}
            </span>
            <div class="flex items-baseline gap-2">
              <span class="text-2xl font-semibold text-n-slate-12">
                {{ formatNumber(reportData.incoming.total) }}
              </span>
              <span
                class="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full border"
                :class="{
                  'text-emerald-700 bg-emerald-50 border-emerald-200':
                    reportData.incoming.trend > 0,
                  'text-rose-700 bg-rose-50 border-rose-200':
                    reportData.incoming.trend < 0,
                  'text-n-slate-11 bg-n-slate-3 border-n-slate-5':
                    reportData.incoming.trend === 0,
                }"
              >
                <span
                  v-if="reportData.incoming.trend > 0"
                  class="i-lucide-arrow-up size-3"
                />
                <span
                  v-else-if="reportData.incoming.trend < 0"
                  class="i-lucide-arrow-down size-3"
                />
                {{ formatTrend(reportData.incoming.trend) }}
              </span>
            </div>
            <span class="text-[11px] text-n-slate-10">
              {{ t('MESSAGES_REPORT.INCOMING_SECTION.VS_PREVIOUS') }}
            </span>
          </div>
        </div>

        <!-- Incoming Chart -->
        <div class="pt-2">
          <div v-if="reportData.incoming.chart_data?.categories?.length">
            <BarChart
              :data="reportData.incoming.chart_data"
              :height="300"
              :aria-label="t('MESSAGES_REPORT.INCOMING_SECTION.TITLE')"
            />
            <!-- Legend -->
            <div
              v-if="reportData.incoming.chart_data.series?.length > 1"
              class="flex flex-wrap items-center gap-4 mt-4 pt-3 border-t border-n-weak"
            >
              <div
                v-for="(item, idx) in reportData.incoming.chart_data.series"
                :key="item.id"
                class="flex items-center gap-2 text-xs"
              >
                <span
                  class="inline-block size-2.5 rounded-full"
                  :class="getSeriesColorClass(item, idx)"
                />
                <span class="text-n-slate-12 font-medium">{{
                  item.label
                }}</span>
              </div>
            </div>
          </div>
          <div v-else class="text-center py-12 text-sm text-n-slate-11">
            {{ t('MESSAGES_REPORT.EMPTY_STATE') }}
          </div>
        </div>
      </div>

      <!-- Section 2: Outgoing Messages -->
      <div
        class="p-6 bg-n-solid-2 border border-n-weak rounded-xl flex flex-col gap-5"
      >
        <div
          class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak pb-4"
        >
          <div class="flex items-center gap-2">
            <span class="i-lucide-arrow-up-right size-5 text-teal-600" />
            <h3 class="text-base font-semibold text-n-slate-12 mb-0">
              {{ t('MESSAGES_REPORT.OUTGOING_SECTION.TITLE') }}
            </h3>
          </div>

          <!-- Outgoing Group By Toggle (By Status vs By Inbox) -->
          <div class="flex items-center gap-2">
            <span class="text-xs font-medium text-n-slate-11">
              {{ t('MESSAGES_REPORT.OUTGOING_SECTION.GROUP_BY_LABEL') }}
            </span>
            <div
              class="flex items-center rounded-lg border border-n-weak p-0.5 bg-n-surface-1"
            >
              <button
                type="button"
                :class="
                  outgoingGroupBy === 'status'
                    ? 'bg-n-solid-2 shadow-sm font-medium text-n-slate-12'
                    : 'text-n-slate-11 hover:text-n-slate-12'
                "
                class="px-2.5 py-1 text-xs rounded-md transition-colors"
                @click="setOutgoingGroupBy('status')"
              >
                {{ t('MESSAGES_REPORT.OUTGOING_SECTION.GROUP_BY_STATUS') }}
              </button>
              <button
                type="button"
                :class="
                  outgoingGroupBy === 'inbox'
                    ? 'bg-n-solid-2 shadow-sm font-medium text-n-slate-12'
                    : 'text-n-slate-11 hover:text-n-slate-12'
                "
                class="px-2.5 py-1 text-xs rounded-md transition-colors"
                @click="setOutgoingGroupBy('inbox')"
              >
                {{ t('MESSAGES_REPORT.OUTGOING_SECTION.GROUP_BY_INBOX') }}
              </button>
            </div>
          </div>
        </div>

        <!-- Outgoing 3 Summary Stat Tiles -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <!-- Total Outgoing -->
          <div
            class="flex flex-col gap-1 p-4 rounded-lg bg-n-surface-1 border border-n-weak"
          >
            <span class="text-xs font-medium text-n-slate-11">
              {{ t('MESSAGES_REPORT.OUTGOING_SECTION.TOTAL') }}
            </span>
            <div class="flex items-baseline gap-2">
              <span class="text-2xl font-semibold text-n-slate-12">
                {{ formatNumber(reportData.outgoing.total) }}
              </span>
              <span
                class="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full border"
                :class="{
                  'text-emerald-700 bg-emerald-50 border-emerald-200':
                    reportData.outgoing.trend > 0,
                  'text-rose-700 bg-rose-50 border-rose-200':
                    reportData.outgoing.trend < 0,
                  'text-n-slate-11 bg-n-slate-3 border-n-slate-5':
                    reportData.outgoing.trend === 0,
                }"
              >
                <span
                  v-if="reportData.outgoing.trend > 0"
                  class="i-lucide-arrow-up size-3"
                />
                <span
                  v-else-if="reportData.outgoing.trend < 0"
                  class="i-lucide-arrow-down size-3"
                />
                {{ formatTrend(reportData.outgoing.trend) }}
              </span>
            </div>
            <span class="text-[11px] text-n-slate-10">
              {{ t('MESSAGES_REPORT.OUTGOING_SECTION.VS_PREVIOUS') }}
            </span>
          </div>

          <!-- Delivery Rate -->
          <div
            class="flex flex-col gap-1 p-4 rounded-lg bg-n-surface-1 border border-n-weak"
          >
            <span class="text-xs font-medium text-n-slate-11">
              {{ t('MESSAGES_REPORT.OUTGOING_SECTION.DELIVERY_RATE') }}
            </span>
            <div class="flex items-baseline gap-2">
              <span class="text-2xl font-semibold text-teal-700">
                {{ formatPercent(reportData.outgoing.delivery_rate) }}
              </span>
              <span
                class="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full border"
                :class="{
                  'text-emerald-700 bg-emerald-50 border-emerald-200':
                    reportData.outgoing.delivery_rate_trend > 0,
                  'text-rose-700 bg-rose-50 border-rose-200':
                    reportData.outgoing.delivery_rate_trend < 0,
                  'text-n-slate-11 bg-n-slate-3 border-n-slate-5':
                    reportData.outgoing.delivery_rate_trend === 0,
                }"
              >
                <span
                  v-if="reportData.outgoing.delivery_rate_trend > 0"
                  class="i-lucide-arrow-up size-3"
                />
                <span
                  v-else-if="reportData.outgoing.delivery_rate_trend < 0"
                  class="i-lucide-arrow-down size-3"
                />
                {{ formatTrend(reportData.outgoing.delivery_rate_trend) }}
              </span>
            </div>
            <span class="text-[11px] text-n-slate-10">
              {{
                t('MESSAGES_REPORT.OUTGOING_SECTION.DELIVERED_COUNT', {
                  count: formatNumber(reportData.outgoing.delivered_count),
                })
              }}
            </span>
          </div>

          <!-- Error Rate -->
          <div
            class="flex flex-col gap-1 p-4 rounded-lg bg-n-surface-1 border border-n-weak"
          >
            <span class="text-xs font-medium text-n-slate-11">
              {{ t('MESSAGES_REPORT.OUTGOING_SECTION.ERROR_RATE') }}
            </span>
            <div class="flex items-baseline gap-2">
              <span
                class="text-2xl font-semibold"
                :class="
                  reportData.outgoing.error_rate > 5
                    ? 'text-rose-700'
                    : 'text-n-slate-12'
                "
              >
                {{ formatPercent(reportData.outgoing.error_rate) }}
              </span>
              <span
                class="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full border"
                :class="{
                  'text-emerald-700 bg-emerald-50 border-emerald-200':
                    reportData.outgoing.error_rate_trend < 0,
                  'text-rose-700 bg-rose-50 border-rose-200':
                    reportData.outgoing.error_rate_trend > 0,
                  'text-n-slate-11 bg-n-slate-3 border-n-slate-5':
                    reportData.outgoing.error_rate_trend === 0,
                }"
              >
                <span
                  v-if="reportData.outgoing.error_rate_trend > 0"
                  class="i-lucide-arrow-up size-3"
                />
                <span
                  v-else-if="reportData.outgoing.error_rate_trend < 0"
                  class="i-lucide-arrow-down size-3"
                />
                {{ formatTrend(reportData.outgoing.error_rate_trend) }}
              </span>
            </div>
            <span class="text-[11px] text-n-slate-10">
              {{
                t('MESSAGES_REPORT.OUTGOING_SECTION.FAILED_COUNT', {
                  count: formatNumber(reportData.outgoing.failed_count),
                })
              }}
            </span>
          </div>
        </div>

        <!-- Outgoing Chart -->
        <div class="pt-2">
          <div v-if="reportData.outgoing.chart_data?.categories?.length">
            <BarChart
              :data="reportData.outgoing.chart_data"
              :height="320"
              :aria-label="t('MESSAGES_REPORT.OUTGOING_SECTION.TITLE')"
            />
            <!-- Legend -->
            <div
              v-if="reportData.outgoing.chart_data.series?.length"
              class="flex flex-wrap items-center gap-4 mt-4 pt-3 border-t border-n-weak"
            >
              <div
                v-for="(item, idx) in reportData.outgoing.chart_data.series"
                :key="item.id"
                class="flex items-center gap-2 text-xs"
              >
                <span
                  class="inline-block size-2.5 rounded-full"
                  :class="getSeriesColorClass(item, idx)"
                />
                <span class="text-n-slate-12 font-medium">{{
                  item.label
                }}</span>
              </div>
            </div>
          </div>
          <div v-else class="text-center py-12 text-sm text-n-slate-11">
            {{ t('MESSAGES_REPORT.EMPTY_STATE') }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
