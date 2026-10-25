# Raqmi Connect: Session Checkpoint & Agent Memory

**Last Updated**: October 25, 2026 (14:00 UTC+4)  
**Active Branch**: `feat/pdf-attachment-preview` (derived from `custom-main`, tracking `upstream/master`)  
**Git Remote**:
- `upstream`: `https://github.com/chatwoot/chatwoot.git`
- `origin`: `https://github.com/mbdali/chatwoot.git`
- `brand-assets`: `https://github.com/mbdali/raqmilabs-brand-assets`

---

## 1. Project & Branding Specifications

- **Brand / Application Name**: `Raqmi Connect`
- **Parent Company**: `Raqmi Labs` ([https://raqmilabs.com](https://raqmilabs.com))
- **Primary Brand Color**: `#2E7D32` (Forest Green - official Raqmi Connect brand tile)
- **Hover / Action Color**: `#1B5E20`
- **Light Tint**: `#E8F5E9`
- **Mark & Text Base**: Zinc Black `#09090B` (light mode), White `#FFFFFF` (dark mode)
- **Tagline**: Premier Customer Engagement & Communication Platform
- **Terms & Privacy**: `https://raqmilabs.com/terms` / `https://raqmilabs.com/privacy`
- **Official Brand Assets Source**: `/home/mbdali/Projects/raqmilabs-brand-assets/products/raqmi-connect/`

---

## 2. Completed Milestones

### A. Official Brand Asset Integration & White-Labeling
1. **Official Raqmi Connect Emblem & SVGs**:
   - Direct import from `raqmilabs-brand-assets/products/raqmi-connect/`.
   - `public/brand-assets/logo_thumbnail.svg` & `public/custom-brand/logo_thumbnail.svg`: Official `#2E7D32` squircle tile with white geometric cutout stripes.
   - `public/brand-assets/logo.svg` & `public/custom-brand/logo.svg`: Horizontal light lockup with official emblem and bold `Raqmi Connect` wordmark (`#09090B` + `#2E7D32`) + `POWERED BY RAQMI LABS`.
   - `public/brand-assets/logo_dark.svg` & `public/custom-brand/logo_dark.svg`: Dark mode horizontal lockup with white/green typography.
2. **Complete Favicon & Mobile Icon Suite**:
   - `favicon.ico`: Embedded multi-resolution ICO (16x16, 32x32, 48x48).
   - `favicon.svg`: Vector SVG favicon.
   - `favicon-*.png`: Exact raster sizes (16, 32, 96, 512 px).
   - `favicon-badge-*.png`: Generated notification unread badges with high-contrast red indicator dot on top right.
   - Apple Touch & Android Icons: Full sizes (57, 60, 72, 76, 114, 120, 144, 152, 180, 192 px) and Windows tiles.
   - `public/manifest.json`: Web app manifest configured with name `"Raqmi Connect"` and theme color `#2E7D32`.
3. **Core Conflict-Free Branding Architecture**:
   - `theme/brand-colors.js` and `app/javascript/dashboard/assets/scss/custom-brand.scss` configured with `#2E7D32`.
   - Startup sync via `config/initializers/custom_branding.rb` keeping `.env` values in sync with `InstallationConfig`.
   - Super admin layouts (`app/views/super_admin/application/_brand.html.erb` & `_standalone.html.erb`) fully white-labeled.

### B. WhatsApp Web In-Place Search
1. **Conversation Search Bar ([`ConversationSearchInput.vue`](file:///home/mbdali/Projects/chatwoot/app/javascript/dashboard/components-next/Conversation/search/ConversationSearchInput.vue))**:
   - Positioned at the top of the conversation list in [`ChatList.vue`](file:///home/mbdali/Projects/chatwoot/app/javascript/dashboard/components/ChatList.vue) directly below the header.
   - Rounded container with WhatsApp Web aesthetic, placeholder, inline spinner, back button (`←`), and clear button (`✕`).
   - Quick keyboard shortcuts: `/` or `⌘K`/`Ctrl+K` to focus; `Escape` to clear/blur.
2. **Category Filter Tabs & Real-Time Results ([`ConversationSearchResults.vue`](file:///home/mbdali/Projects/chatwoot/app/javascript/dashboard/components-next/Conversation/search/ConversationSearchResults.vue))**:
   - Category pills for **All**, **Chats**, **Messages**, and **Contacts** with live match count badges.
   - In-place search result cards with matched keyword highlighting.
   - Direct click-to-open: opens chat, jumps directly to message (`messageId`), or navigates to contact conversations.
3. **Debounced Query Execution**:
   - 300ms debounced full-search dispatching to Vuex store `conversationSearch/fullSearch`.

### C. WhatsApp-Style PDF Preview & Actions
1. **In-Chat PDF Card Preview**:
   - WhatsApp-style PDF card with first-page preview canvas rendering.
   - File size, page count, and title metadata display.
2. **PDF Viewer Modal & Action Toolbar**:
   - Modal action toolbar with WhatsApp-inspired controls: Message, Pin, Star, Forward, React/Emoji, Download, and Go to Message (`message-square-text` icon).
   - Localized tooltips and proper accessibility labels.

### D. Docker & Development Workflow
1. **Full Production Image Built & Cached**:
   - Cached C++ gems (`grpc`), Google Cloud Storage, Dialogflow, and Google Translate dependencies.
2. **Fast Local Live Mounting**:
   - Configured via `docker-compose.override.yml` (`./app`, `./config`, `./theme` mounted live).
   - Brand assets in `public/`: instant reload (0s).
   - Rails code/configs: `docker compose restart rails` (~2s).

---

## 3. Key Commands to Resume

### Start the Platform
```bash
docker compose up -d
```
Access at: **http://localhost:3000** (Super Admin: **http://localhost:3000/super_admin/accounts**)

### Fast Reloading (When Editing Code)
- **Branding Assets** (`public/custom-brand/`): Refresh browser (0s)
- **Ruby Code & Configs** (`app/`, `config/`): `docker compose restart rails` (~2s)
- **Frontend Rebuild** (if changing Vue/JS): `pnpm dev` or `docker compose build && docker compose up -d`

### Upstream Synchronization
```bash
# Automated safe merge from upstream/master:
git sync-upstream
```

---

## 4. Recent Git Commit History
- `2d2f2c76be`: `feat(conversation): add whatsapp-style in-place search to conversation list`
- `12872f49dd`: `feat(message): change go to message icon to message-square-text in pdf viewer modal`
- `deca37c3c3`: `fix(message): resolve close button hover tooltip i18n key`
- `cdd1142f25`: `feat(message): add emoji react icon to pdf viewer modal actions`
- `d970c0e2d3`: `feat(message): update pdf viewer actions with message, star, pin, and forward icons`
- `06bcb81be4`: `feat(message): add whatsapp-style pdf preview with first page rendering`
- `b701ddc674`: `feat(theme): apply warm parchment and forest green color palette`
- `d3c3422f57`: `docs: save session checkpoint and memory for Raqmi Connect`
- `02fc4a3ee9`: `docs(brand): update file architecture with super_admin and favicon assets`
- `f2ca995fae`: `feat(branding): customize super_admin header, title, and all brand favicons for Raqmi Connect`
- `6d7dcc53cc`: `docs(docker): update command help with live mounting and fast reload workflow`
- `9426943504`: `feat(docker): add docker-compose.override.yml for local live code mounting`
- `6e59b314f3`: `fix(docker): restore standard bundle dependencies for Zeitwerk eager loading`
- `8ac26c87fb`: `chore(docker): remove obsolete version attribute from docker-compose.yml`
- `460bd7075e`: `fix(theme): use hex color for n.brand to support Tailwind opacity modifiers in PostCSS`
