# Raqmi Connect: Session Checkpoint & Agent Memory

**Last Updated**: October 25, 2026 (01:25 UTC+4)  
**Branch**: `custom-main` (clean working tree, branched off `master` tracking `upstream/master`)  
**Git Remote**:
- `upstream`: `https://github.com/chatwoot/chatwoot.git`
- `origin`: `https://github.com/mbdali/chatwoot.git`

---

## 1. Project & Branding Specifications

- **Brand / Application Name**: `Raqmi Connect`
- **Parent Company**: `Raqmi Labs` ([https://raqmilabs.com](https://raqmilabs.com))
- **Primary Color**: `#FF5A09` (Deep Orange)
- **Accent Gradient**: `#FF5A09` (0%) → `#EC7F37` (50%) → `#BE4F0C` (100%)
- **Dark Mode Primary**: `#FF6E26`
- **Tagline**: Premier Customer Engagement & Communication Platform
- **Terms & Privacy**: `https://raqmilabs.com/terms` / `https://raqmilabs.com/privacy`

---

## 2. Completed Milestones

### A. Core Architecture & Conflict-Free Branding
1. **Zero `.vue` Component Churn**: Upstream `.vue` components remain 100% untouched.
2. **Modular Palette**: Isolated in `theme/brand-colors.js` and `app/javascript/dashboard/assets/scss/custom-brand.scss`.
3. **Automatic Startup Sync**: `config/initializers/custom_branding.rb` syncs `.env` white-label values directly to the `InstallationConfig` database table on boot and purges Redis cache.
4. **Isolated Brand Assets**: Vector SVGs and high-res PNGs in `public/custom-brand/` (`logo.svg`, `logo_dark.svg`, `logo_thumbnail.svg`, `favicon.svg`, `favicon.ico`, etc.).

### B. Super Admin & Full App White-Labeling
1. **Brand Header**: `app/views/super_admin/application/_brand.html.erb` renders dynamic `Raqmi Connect v<version>` and custom logo thumbnail.
2. **Tab / Window Title**: `app/helpers/super_admin/navigation_helper.rb` overrides `application_title` to output `Raqmi Connect`.
3. **Login / Standalone Layout**: `app/views/super_admin/application/_standalone.html.erb` renders Raqmi Connect title, favicons, and logos.
4. **All Favicons & App Icons**: Mirrored across `public/brand-assets/` and all `public/favicon*.png`, `apple-icon*.png`, and `android-icon*.png` in Raqmi orange theme.

### C. Docker & Live Development Workflow
1. **Full Production Image Built & Cached**:
   - Includes Google Cloud Storage, Dialogflow, gRPC, and Google Translate.
   - All native C++ gems (`grpc`) compiled and permanently cached in Docker layer.
2. **Local Live Mounting (Option 2)**:
   - Configured via `docker-compose.override.yml` (`./app`, `./config`, `./theme` mounted live).
   - Any brand asset changes in `public/custom-brand/`: **Instant (0s)** on browser refresh.
   - Any Ruby code or config changes: Take effect with `docker compose restart rails` (**~2s**). No image rebuild needed!
3. **Production Mode Ready**:
   - `docker-compose.yml` runs pure image without local code overrides.

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
- **Frontend Assets Rebuild** (if changing Vue/SCSS): `docker compose build && docker compose up -d` (~35s, gems remain cached)

### Upstream Synchronization
```bash
# Automated safe merge from upstream/master:
git sync-upstream
```

---

## 4. Git Commit History on `custom-main`
- `02fc4a3ee9`: docs(brand): update file architecture with super_admin and favicon assets
- `f2ca995fae`: feat(branding): customize super_admin header, title, and all brand favicons for Raqmi Connect
- `6d7dcc53cc`: docs(docker): update command help with live mounting and fast reload workflow
- `9426943504`: feat(docker): add docker-compose.override.yml for local live code mounting
- `6e59b314f3`: fix(docker): restore standard bundle dependencies for Zeitwerk eager loading
- `8ac26c87fb`: chore(docker): remove obsolete version attribute from docker-compose.yml
- `460bd7075e`: fix(theme): use hex color for n.brand to support Tailwind opacity modifiers in PostCSS
- `6e8a3a6f4f`: docs(branding): add comprehensive brand guide for Raqmi Connect
- `d9c8b3f268`: feat(branding): update app name to Raqmi Connect across configs and assets
- `e0f64d4b2b`: feat(branding): add environment auto-sync initializer for white-label config
- `9f696279c4`: feat(branding): add isolated static brand assets
- `1d93b9d6cf`: chore(sync): add upstream sync script and documentation
