# Brand Guidelines & White-Label Reference: Raqmi Connect

Welcome to the brand identity guide for **Raqmi Connect**, a customized customer conversation and engagement platform developed by **Raqmi Labs**.

This document outlines the brand assets, color palette, typography, white-label configurations, and technical architecture implemented to ensure seamless future upgrades from the upstream repository.

---

## 1. Brand Overview

- **Product / Application Name**: `Raqmi Connect`
- **Parent Company**: `Raqmi Labs`
- **Official Website**: [https://raqmilabs.com](https://raqmilabs.com)
- **Official Brand Assets Repository**: [https://github.com/mbdali/raqmilabs-brand-assets](https://github.com/mbdali/raqmilabs-brand-assets) (`products/raqmi-connect/`)
- **Tagline**: Premier Customer Engagement & Communication Platform
- **Support & Sales Contact**: `sales@raqmilabs.com`
- **Terms of Service**: `https://raqmilabs.com/terms`
- **Privacy Policy**: `https://raqmilabs.com/privacy`

---

## 2. Color System & Design Tokens

Raqmi Connect utilizes the official **RaqmiConnect Green** product palette (`#2E7D32`), balanced with modern Zinc/Slate neutrals for high contrast and accessibility (passes WCAG AA 5.1:1 on white text).

### 2.1 Core Palette

| Token | Hex Code | RGB | Usage |
|---|---|---|---|
| **Primary Brand** | `#2E7D32` | `46, 125, 50` | Main CTA buttons, active tabs, focus rings, brand badges, links |
| **Hover / Text Buttons** | `#1B5E20` | `27, 94, 32` | Button hover states, active pressed states |
| **Light Tint** | `#E8F5E9` | `232, 245, 233` | Badges, subtle active item backgrounds, tint highlights |
| **Dark Mode Primary** | `#4CAF50` | `76, 175, 80` | High-contrast accent elements on dark backgrounds |
| **Mark Zinc Black** | `#09090B` | `9, 9, 11` | Primary text and dark logos (matches RaqmiERP) |
| **Neutral Slate** | `#111827` | `17, 24, 39` | High-contrast typography |

### 2.2 Brand Green Palette Scale

```javascript
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
}
```

### 2.3 Tailwind & CSS Token Mapping

The color palette is modularly mapped without modifying core upstream Vue components:

- **Tailwind Token (`n.brand`)**: Mapped to `#2E7D32` in `theme/brand-colors.js`.
- **Legacy Tokens (`woot-500` .. `woot-700`)**: Remapped to the Raqmi Connect green palette.
- **CSS Custom Properties** (defined in `app/javascript/dashboard/assets/scss/custom-brand.scss`):
  ```scss
  :root {
    --brand-color: #2E7D32;
    --brand-color-accent: #388E3C;
    --brand-color-dark: #1B5E20;
    --brand-color-rgb: 46, 125, 50;
  }

  [data-theme='dark'],
  .dark {
    --brand-color: #4CAF50;
    --brand-color-accent: #66BB6A;
    --brand-color-dark: #388E3C;
    --brand-color-rgb: 76, 175, 80;
  }
  ```

---

## 3. Logo & Visual Assets

All official brand visual assets are stored in `public/custom-brand/` and mirrored in `public/brand-assets/`:
```
public/custom-brand/
├── logo.svg              # Primary horizontal lockup for light backgrounds
├── logo_dark.svg         # Primary horizontal lockup for dark backgrounds
├── logo_thumbnail.svg    # Official Raqmi Connect squircle emblem (512x512)
├── logo.png              # Raster logo fallback
├── logo-thumbnail.png    # Raster square thumbnail fallback
├── favicon.svg           # Vector browser favicon
├── favicon.ico           # Multi-resolution ICO (16x16, 32x32, 48x48)
├── favicon-16x16.png     # 16px raster favicon
└── favicon-32x32.png     # 32px raster favicon
```

### 3.1 Emblem Anatomy
The official Raqmi Connect icon from `raqmilabs-brand-assets/products/raqmi-connect/`:
1. **Background Tile**: Rounded squircle (`fill="#2E7D32"`) providing high contrast.
2. **Cutout Matrix**: Solid white lines cutting through the tile, forming the signature stylized Raqmi identity.
3. **Universality**: Works cleanly on light and dark backgrounds without modification.

### 3.2 Asset Usage Guidelines

| Context | Recommended Asset | Notes |
|---|---|---|
| **Login / Onboarding** | `logo.svg` / `logo_dark.svg` | Displayed above authentication forms |
| **Dashboard Top Nav / Sidebar** | `logo_thumbnail.svg` | 32x32px or 40x40px square emblem |
| **Browser Tab** | `favicon.svg` / `favicon.ico` | Scales sharply down to 16x16px |
| **Notification Badges** | `favicon-badge-*.png` | Displays red unread alert dot on top right |
| **Widget Header** | `logo_thumbnail.svg` | Displayed in visitor chat bubble and launcher |

---

## 4. White-Label Environment Configuration

The following variables in `.env` govern user-facing names and links:

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
├── docker-compose.override.yml                     [Local live code mounting]
├── config/initializers/custom_branding.rb          [New Standalone File]
├── public/custom-brand/                            [New Standalone Directory]
│   ├── favicon.svg, favicon.ico, favicon-*.png
│   ├── logo.svg, logo.png
│   ├── logo_dark.svg
│   └── logo_thumbnail.svg, logo_thumbnail.png
├── public/brand-assets/                            [Raqmi Connect SVGs mirrored]
├── theme/
│   ├── colors.js                                   [Pristine Upstream]
│   └── brand-colors.js                             [New Standalone File]
├── app/helpers/super_admin/navigation_helper.rb    [application_title override]
├── app/views/super_admin/application/_brand.html.erb [Dynamic brand name & logo]
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
