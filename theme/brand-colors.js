import { colors } from './colors';

export const brandColors = {
  // Theme color tokens (HSL with alpha support)
  background: 'hsl(var(--background) / <alpha-value>)',
  foreground: 'hsl(var(--foreground) / <alpha-value>)',
  card: {
    DEFAULT: 'hsl(var(--card) / <alpha-value>)',
    foreground: 'hsl(var(--card-foreground) / <alpha-value>)',
  },
  popover: {
    DEFAULT: 'hsl(var(--popover) / <alpha-value>)',
    foreground: 'hsl(var(--popover-foreground) / <alpha-value>)',
  },
  primary: {
    DEFAULT: 'hsl(var(--primary) / <alpha-value>)',
    foreground: 'hsl(var(--primary-foreground) / <alpha-value>)',
  },
  secondary: {
    DEFAULT: 'hsl(var(--secondary) / <alpha-value>)',
    foreground: 'hsl(var(--secondary-foreground) / <alpha-value>)',
  },
  muted: {
    DEFAULT: 'hsl(var(--muted) / <alpha-value>)',
    foreground: 'hsl(var(--muted-foreground) / <alpha-value>)',
  },
  accent: {
    DEFAULT: 'hsl(var(--accent) / <alpha-value>)',
    foreground: 'hsl(var(--accent-foreground) / <alpha-value>)',
  },
  destructive: {
    DEFAULT: 'hsl(var(--destructive) / <alpha-value>)',
    foreground: 'hsl(var(--destructive-foreground) / <alpha-value>)',
  },
  border: 'hsl(var(--border) / <alpha-value>)',
  input: 'hsl(var(--input) / <alpha-value>)',
  ring: 'hsl(var(--ring) / <alpha-value>)',
  chart: {
    1: 'hsl(var(--chart-1) / <alpha-value>)',
    2: 'hsl(var(--chart-2) / <alpha-value>)',
    3: 'hsl(var(--chart-3) / <alpha-value>)',
    4: 'hsl(var(--chart-4) / <alpha-value>)',
    5: 'hsl(var(--chart-5) / <alpha-value>)',
  },
  sidebar: {
    DEFAULT: 'hsl(var(--sidebar) / <alpha-value>)',
    foreground: 'hsl(var(--sidebar-foreground) / <alpha-value>)',
    primary: 'hsl(var(--sidebar-primary) / <alpha-value>)',
    'primary-foreground': 'hsl(var(--sidebar-primary-foreground) / <alpha-value>)',
    accent: 'hsl(var(--sidebar-accent) / <alpha-value>)',
    'accent-foreground': 'hsl(var(--sidebar-accent-foreground) / <alpha-value>)',
    border: 'hsl(var(--sidebar-border) / <alpha-value>)',
    ring: 'hsl(var(--sidebar-ring) / <alpha-value>)',
  },

  // Modern Chatwoot brand color token
  n: {
    ...colors.n,
    brand: '#2E7D32',
  },
  // Dedicated brand palette
  brand: {
    DEFAULT: '#2E7D32',
    50: '#e8f5e9',
    100: '#c8e6c9',
    200: '#a5d6a7',
    300: '#81c784',
    400: '#66bb6a',
    500: '#2E7D32',
    600: '#276c2b',
    700: '#1b5e20',
    800: '#144618',
    900: '#0d3010',
  },
  // Legacy woot color mappings
  woot: {
    ...colors.woot,
    500: '#2E7D32',
    600: '#276c2b',
    700: '#1b5e20',
  },
};
