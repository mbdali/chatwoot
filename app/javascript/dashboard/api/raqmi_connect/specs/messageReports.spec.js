import messageReportsAPI, { fetchMessageReports } from '../messageReports';

describe('Message Reports API (Raqmi Connect)', () => {
  const originalAxios = window.axios;
  const axiosMock = {
    get: vi.fn(() => Promise.resolve({ data: {} })),
  };

  beforeEach(() => {
    window.axios = axiosMock;
  });

  afterEach(() => {
    window.axios = originalAxios;
    vi.clearAllMocks();
  });

  it('calls the message reports endpoint with timezone offset and parameters', async () => {
    const params = {
      since: 1729000000,
      until: 1729600000,
      inbox_id: 42,
      group_by: 'week',
      outgoing_group_by: 'status',
    };

    await fetchMessageReports(1, params);

    expect(axiosMock.get).toHaveBeenCalledWith(
      '/api/v1/accounts/1/reports/messages',
      {
        params: expect.objectContaining({
          ...params,
          timezone_offset: expect.any(Number),
        }),
      }
    );
  });

  it('exposes fetchMessageReports on the default export', () => {
    expect(messageReportsAPI.fetchMessageReports).toBeDefined();
  });
});
