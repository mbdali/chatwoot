# Brand Guidelines & White-Label Reference: Raqmi Connect

Welcome to the brand identity guide for **Raqmi Connect**, a customized customer conversation and engagement platform developed by **Raqmi Labs**.

This document outlines the brand assets, color palette, typography, white-label configurations, and technical architecture implemented to ensure seamless future upgrades from the upstream repository.

---

## 1. Brand Overview

- **Product / Application Name**: `Raqmi Connect`
- **Parent Company**: `Raqmi Labs`
- **Official Website**: [https://raqmilabs.com](https://raqmilabs.com)
- **Tagline**: Premier Customer Engagement & Communication Platform
- **Support & Sales Contact**: `sales@raqmilabs.com`
- **Terms of Service**: `https://raqmilabs.com/terms`
- **Privacy Policy**: `https://raqmilabs.com/privacy`

---

## 2. Color System & Design Tokens

Raqmi Connect features a vibrant, high-energy orange palette derived from the Raqmi Labs visual identity, balanced with modern slate neutrals for maximum legibility in both light and dark themes.

### 2.1 Core Palette

| Token | Hex Code | RGB | Usage |
|---|---|---|---|
| **Primary Brand** | `#FF5A09` | `255, 90, 9` | Main CTA buttons, active tabs, focus rings, brand badges, links |
| **Accent / Gradient Mid** | `#EC7F37` | `236, 127, 55` | Gradients, hover states, secondary accents |
| **Dark Accent / Shadow** | `#BE4F0C` | `190, 79, 12` | Gradient shadows, pressed button states |
| **Dark Mode Primary** | `#FF6E26` | `255, 110, 38` | High-contrast brand elements on dark backgrounds |
| **Neutral Dark** | `#393939` | `57, 57, 57` | Headers, primary body text in light mode |
| **Neutral Slate** | `#111827` | `17, 24, 39` | High-contrast typography |

### 2.2 Gradient Specifications

The official Raqmi Connect brand gradient is linear at a 135° diagonal:
```css
background: linear-gradient(135deg, #FF5A09 0%, #EC7F37 50%, #BE4F0C 100%);
```

### 2.3 Tailwind & CSS Token Mapping

The color palette is modularly mapped without modifying core Vue components:

- **Tailwind Token (`n.brand`)**: Mapped to `var(--brand-color, #FF5A09)` in `theme/brand-colors.js`.
- **Legacy Tokens (`woot-500` .. `woot-700`)**: Remapped to the brand orange palette.
- **CSS Custom Properties** (defined in `app/javascript/dashboard/assets/scss/custom-brand.scss`):
  ```scss
  :root {
    --brand-color: #FF5A09;
    --brand-color-accent: #EC7F37;
    --brand-color-dark: #BE4F0C;
    --brand-color-rgb: 255, 90, 9;
  }

  [data-theme='dark'] {
    --brand-color: #FF6E26;
    --brand-color-accent: #FF8544;
    --brand-color-dark: #EC7F37;
  }
  ```

---

## 3. Logo & Visual Assets

All brand visual assets are stored in the dedicated, isolated directory:
```
public/custom-brand/
├── logo.svg              # Primary logo for light backgrounds
├── logo_dark.svg         # Primary logo for dark backgrounds
├── logo_thumbnail.svg    # Square app icon & collapsed sidebar emblem (512x512)
└── favicon.svg           # High-resolution vector browser favicon
```

### 3.1 Emblem Anatomy
The Raqmi icon blends technology and communication:
1. **Background**: Rounded squircle (`rx="112"`) with the 3-stop Raqmi gradient.
2. **Circuit Matrix**: Subtle white grid lines (`stroke-opacity="0.18"`) evoking modern software architecture.
3. **Stylized 'R'**: Bold, continuous path symbolizing connectivity and rapid routing.
4. **Circuit Accent Nodes**: Three satellite dots representing data synchronization and messaging endpoints.

### 3.2 Asset Usage Guidelines

| Context | Recommended Asset | Notes |
|---|---|---|
| **Login / Onboarding** | `logo.svg` / `logo_dark.svg` | Displayed above the authentication forms |
| **Dashboard Top Nav / Sidebar** | `logo_thumbnail.svg` | 32x32px or 40x40px square emblem |
| **Browser Tab** | `favicon.svg` | Scales sharply down to 16x16px |
| **Widget Header** | `logo_thumbnail.svg` | Displayed in visitor chat bubble and launcher |

---

## 4. White-Label Environment Configuration

The following variables in `.env` govern all user-facing names and links:

```bash
# ==========================================
# Raqmi Connect Custom White-Label Branding
# ==========================================
INSTALLATION_NAME="Raqmi Connect"
BRAND_NAME="Raqmi Connect"
BRAND_URL="https://raqmilabs.com"
WIDGET_BRAND_URL="https://raqmilabs.com"
TERMS_URL="https://raqmilabs.com/terms"
PRIVACY_URL="https://raqmilabs.com/privacy"
LOGO="/custom-brand/logo.svg"
LOGO_DARK="/custom-brand/logo_dark.svg"
LOGO_THUMBNAIL="/custom-brand/logo_thumbnail.svg"
LOGO_URL="/custom-brand/logo.svg"
LOGO_THUMBNAIL_URL="/custom-brand/logo_thumbnail.svg"
```

### Automated Startup Sync
The initializer at `config/initializers/custom_branding.rb` runs on application boot:
- Reads the environment variables.
- Automatically writes them to the `InstallationConfig` database table if changed.
- Flushes the Redis Alfred cache (`GlobalConfig.clear_cache`) so changes take effect immediately across all client sessions.

---

## 5. Technical Architecture & Conflict-Free Upgrades

To ensure upstream updates from `upstream/master` can be pulled without merge friction, the following boundaries are strictly maintained:

```
├── .env                                            [Untracked / Git Ignored]
├── config/initializers/custom_branding.rb          [New Standalone File]
├── public/custom-brand/                            [New Standalone Directory]
│   ├── favicon.svg
│   ├── logo.svg
│   ├── logo_dark.svg
│   └── logo_thumbnail.svg
├── theme/
│   ├── colors.js                                   [Pristine Upstream]
│   └── brand-colors.js                             [New Standalone File]
├── app/javascript/
│   ├── dashboard/assets/scss/custom-brand.scss     [New Standalone File]
│   ├── packs/custom-brand.scss                     [New Standalone File]
│   └── entrypoints/dashboard.js                    [Modified: 1 import line]
└── tailwind.config.js                              [Modified: 2 lines: 1 import, 1 spread]
```

### Git Conflict Rules of Thumb:
- **Never edit core `.vue` components** for branding purposes.
- If upstream updates `tailwind.config.js`, preserve `import { brandColors } from './theme/brand-colors';` and `...brandColors,` inside `colors: { ... }`.
- If upstream updates `dashboard.js`, preserve `import 'dashboard/assets/scss/custom-brand.scss';`.
- Use `./bin/sync-upstream` to pull and verify upstream changes automatically.
