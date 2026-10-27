/* global axios */

const getTimeOffset = () => -new Date().getTimezoneOffset() / 60;

// Raqmi Connect: API client for fetching aggregate and per-inbox message reports.
const buildUrl = accountId => {
  return `/api/v1/accounts/${accountId}/reports/messages`;
};

export const fetchMessageReports = (accountId, params = {}) => {
  return axios.get(buildUrl(accountId), {
    params: {
      timezone_offset: getTimeOffset(),
      ...params,
    },
  });
};

export default {
  fetchMessageReports,
};
