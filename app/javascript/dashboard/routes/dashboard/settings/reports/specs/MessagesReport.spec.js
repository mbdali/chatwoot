import { mount, flushPromises } from '@vue/test-utils';
import MessagesReport from '../MessagesReport.vue';
import * as messageReportsApi from 'dashboard/api/raqmi_connect/messageReports';

const mockReportData = {
  incoming: {
    total: 150,
    previous_total: 100,
    trend: 50.0,
    chart_data: {
      categories: ['21 Oct', '22 Oct'],
      series: [
        {
          id: 'inbox_1',
          label: 'WhatsApp Main',
          color: 'rgb(var(--blue-9))',
          data: [75, 75],
        },
      ],
    },
  },
  outgoing: {
    total: 300,
    previous_total: 250,
    trend: 20.0,
    delivered_count: 285,
    delivery_rate: 95.0,
    previous_delivery_rate: 90.0,
    delivery_rate_trend: 5.0,
    failed_count: 15,
    error_rate: 5.0,
    previous_error_rate: 10.0,
    error_rate_trend: -5.0,
    chart_data: {
      categories: ['21 Oct', '22 Oct'],
      series: [
        {
          id: 'status_delivered',
          label: 'Delivered',
          color: 'rgb(var(--teal-9))',
          data: [140, 145],
        },
      ],
    },
  },
};

vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: { accountId: '1' },
    query: {},
  }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

describe('MessagesReport.vue', () => {
  let fetchSpy;
  let mockStore;

  beforeEach(() => {
    fetchSpy = vi
      .spyOn(messageReportsApi, 'fetchMessageReports')
      .mockResolvedValue({ data: mockReportData });

    mockStore = {
      getters: {
        'inboxes/getInboxes': [
          {
            id: 1,
            name: 'WhatsApp Support',
            channel_type: 'Channel::Whatsapp',
          },
          { id: 2, name: 'Website Chat', channel_type: 'Channel::WebWidget' },
        ],
      },
      dispatch: vi.fn(),
    };
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  const createWrapper = () => {
    return mount(MessagesReport, {
      global: {
        mocks: {
          $t: key => key,
        },
        provide: {
          store: mockStore,
        },
        stubs: {
          WootDatePicker: {
            name: 'WootDatePicker',
            template: '<div class="date-picker-stub" />',
            emits: ['date-range-changed'],
          },
          BarChart: {
            name: 'BarChart',
            template: '<div class="bar-chart-stub" />',
            props: ['data', 'height'],
          },
          Select: {
            name: 'Select',
            template:
              '<select :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><option v-for="o in options" :key="o.value" :value="o.value">{{ o.label }}</option></select>',
            props: ['modelValue', 'options'],
            emits: ['update:modelValue'],
          },
          ReportHeader: {
            name: 'ReportHeader',
            template: '<div class="report-header-stub" />',
          },
          Spinner: true,
        },
      },
    });
  };

  it('fetches report data on mount with default filters', async () => {
    const wrapper = createWrapper();
    await flushPromises();

    expect(fetchSpy).toHaveBeenCalledWith(
      '1',
      expect.objectContaining({
        group_by: 'day',
        outgoing_group_by: 'status',
      })
    );

    // Verify incoming and outgoing totals rendered
    expect(wrapper.text()).toContain('150');
    expect(wrapper.text()).toContain('300');
    expect(wrapper.text()).toContain('95.0%');
    expect(wrapper.text()).toContain('5.0%');
  });

  it('switches outgoing group by when toggle buttons are clicked', async () => {
    const wrapper = createWrapper();
    await flushPromises();

    // Click "By Inbox" button
    const buttons = wrapper.findAll('button');
    const inboxGroupButton = buttons.find(b =>
      b.text().includes('MESSAGES_REPORT.OUTGOING_SECTION.GROUP_BY_INBOX')
    );
    expect(inboxGroupButton).toBeDefined();

    await inboxGroupButton.trigger('click');
    await flushPromises();

    expect(fetchSpy).toHaveBeenLastCalledWith(
      '1',
      expect.objectContaining({
        outgoing_group_by: 'inbox',
      })
    );
  });

  it('filters report when an inbox is selected from the dropdown', async () => {
    const wrapper = createWrapper();
    await flushPromises();

    const select = wrapper.findAllComponents({ name: 'Select' })[0];
    await select.vm.$emit('update:modelValue', 1);
    await flushPromises();

    expect(fetchSpy).toHaveBeenLastCalledWith(
      '1',
      expect.objectContaining({
        inbox_id: 1,
      })
    );
  });

  it('changes interval when interval dropdown is changed', async () => {
    const wrapper = createWrapper();
    await flushPromises();

    const select = wrapper.findAllComponents({ name: 'Select' })[1];
    await select.vm.$emit('update:modelValue', 'week');
    await flushPromises();

    expect(fetchSpy).toHaveBeenLastCalledWith(
      '1',
      expect.objectContaining({
        group_by: 'week',
      })
    );
  });

  it('shows empty state when no categories exist', async () => {
    fetchSpy.mockResolvedValueOnce({
      data: {
        incoming: { total: 0, chart_data: { categories: [], series: [] } },
        outgoing: { total: 0, chart_data: { categories: [], series: [] } },
      },
    });

    const wrapper = createWrapper();
    await flushPromises();

    expect(wrapper.text()).toContain('MESSAGES_REPORT.EMPTY_STATE');
  });
});
