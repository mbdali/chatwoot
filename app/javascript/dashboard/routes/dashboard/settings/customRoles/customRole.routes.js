import { FEATURE_FLAGS } from '../../../../featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { frontendURL } from 'dashboard/helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import CustomRolesHome from './Index.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.CUSTOM_ROLES,
  permissions: ['administrator'],
  installationTypes: [
    INSTALLATION_TYPES.COMMUNITY,
    INSTALLATION_TYPES.CLOUD,
    INSTALLATION_TYPES.ENTERPRISE,
  ],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/custom-roles'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'custom_roles_wrapper',
          meta,
          redirect: to => {
            return { name: 'custom_roles_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'custom_roles_list',
          meta,
          component: CustomRolesHome,
        },
      ],
    },
  ],
};
