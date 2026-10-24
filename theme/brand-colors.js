import { colors } from './colors';

export const brandColors = {
  // Override modern Chatwoot brand color token
  n: {
    ...colors.n,
    brand: 'var(--brand-color, #FF5A09)',
  },
  // Dedicated RaqmiChats brand palette
  brand: {
    DEFAULT: '#FF5A09',
    50: '#fff5ed',
    100: '#ffe8d5',
    200: '#ffd0aa',
    300: '#ffb275',
    400: '#ff8a3d',
    500: '#FF5A09',
    600: '#ec7f37',
    700: '#be4f0c',
    800: '#9e2c00',
    900: '#7f2605',
  },
  // Legacy woot color mappings
  woot: {
    ...colors.woot,
    500: '#FF5A09',
    600: '#ec7f37',
    700: '#be4f0c',
  },
};
