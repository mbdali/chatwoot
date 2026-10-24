# Git Upstream Synchronization & Branch Management Guide

This document outlines the workflow and commands for maintaining custom modifications on the `custom-main` branch while staying in sync with the official upstream repository (`chatwoot/chatwoot`).

---

## 1. Architecture & Remote Configuration

- **`origin`**: Your personal GitHub fork (`https://github.com/mbdali/chatwoot.git`).
- **`upstream`**: The official open-source repository (`https://github.com/chatwoot/chatwoot.git`).

To verify your remotes:
```bash
git remote -v
```

---

## 2. Branch Hierarchy

| Branch | Remote Tracking | Purpose | Direct Edits Allowed? |
|---|---|---|---|
| `master` | `upstream/master` | Pristine mirror of upstream production releases | ❌ No |
| `custom-main` | `origin/custom-main` | Dedicated working branch for custom modifications | ✅ Yes |
| `develop` | `origin/develop` | Fork default branch (tracks bleeding-edge development) | Optional |

---

## 3. Upstream Safeguards

To prevent accidental modification of clean upstream tracking branches:
- **Pre-commit hook** (`.git/hooks/pre-commit`): Blocks direct commits made while on `master`.
- **Pre-push hook** (`.husky/pre-push` calling `bin/validate_push`): Prevents accidental push operations targeting `master` or `develop`.

---

## 4. Automated Synchronization

An automated helper script is available at `bin/sync-upstream`. It ensures the working tree is clean, fetches upstream updates, fast-forwards `master` without modifying uncommitted state, merges or rebases upstream into `custom-main`, and highlights merge conflicts if any occur.

### Quick Usage (Git Aliases)

```bash
# Merge strategy (recommended for non-destructive history)
git sync-upstream

# Rebase strategy (for a clean linear history)
git sync-upstream-rebase
```

### CLI Script Options

```bash
# Merge upstream/master into custom-main (default)
./bin/sync-upstream --merge

# Rebase custom-main onto upstream/master
./bin/sync-upstream --rebase

# Sync from a different upstream branch (e.g., develop)
./bin/sync-upstream --merge develop
```

---

## 5. Manual Synchronization Workflows

If you prefer executing git commands manually:

### Option A: Merge Strategy (Recommended)

Keeps all historical commits intact with clear merge checkpoints.

```bash
# 1. Ensure working directory is clean
git status

# 2. Fetch updates and tags from upstream
git fetch upstream --tags --prune

# 3. Fast-forward pristine local master branch without checking it out
git fetch upstream master:master

# 4. Switch to custom-main
git checkout custom-main

# 5. Merge upstream changes into custom-main
git merge upstream/master

# 6. Push updated branch to your fork
git push origin custom-main
```

### Option B: Rebase Strategy

Replays custom commits on top of new upstream commits for a flat, linear commit graph.

```bash
# 1. Ensure working directory is clean
git status

# 2. Fetch updates and tags from upstream
git fetch upstream --tags --prune
git fetch upstream master:master

# 3. Switch to custom-main
git checkout custom-main

# 4. Rebase custom-main onto upstream/master
git rebase upstream/master

# 5. Push to your fork (requires force-with-lease after rebasing)
git push --force-with-lease origin custom-main
```

---

## 6. Conflict Resolution Guide

When upstream modifies lines that conflict with your custom changes, Git halts and flags the conflicting files.

### 1. Identify Conflicted Files
```bash
git status
# or list only conflicting files:
git diff --name-only --diff-filter=U
```

### 2. Resolve Conflict Markers
Open each conflicted file and look for conflict markers:
```text
<<<<<<< HEAD (Current Changes in custom-main)
your custom logic
=======
upstream incoming logic
>>>>>>> upstream/master
```
Edit the file to preserve the desired logic and delete the marker lines.

### 3. Stage Resolved Files
```bash
git add <path/to/resolved-file>
```

### 4. Complete the Operation

- **If resolving a Merge:**
  ```bash
  git commit
  ```
  *(To abort the merge: `git merge --abort`)*

- **If resolving a Rebase:**
  ```bash
  git rebase --continue
  ```
  *(To abort the rebase: `git rebase --abort`)*

---

## 7. Pushing Custom Changes to GitHub

When you commit new changes or sync updates on `custom-main`:

```bash
# First-time push to set upstream tracking on your fork
git push -u origin custom-main

# Subsequent regular pushes
git push origin custom-main
```

---

## 8. Custom Branding Architecture (RaqmiChats)

To ensure upstream updates merge with minimal friction, custom branding is isolated away from core files.

### Branding Details
- **Brand / App Name**: RaqmiChats
- **Company**: Raqmi Labs (`https://raqmilabs.com`)
- **Primary Brand Color**: `#FF5A09` (Deep Orange)
- **Accent / Gradient**: `#FF5A09` → `#EC7F37` → `#BE4F0C`
- **Dark Theme Accent**: `#FF6E26`

### File Registry

| File / Directory | Change Type | Purpose | Git Conflict Risk |
|---|---|---|---|
| `.env` | Untracked / Ignored | Built-in white-label environment variables | 🟢 Zero (git-ignored) |
| `public/custom-brand/` | New Directory | Isolated SVGs (`logo.svg`, `logo_dark.svg`, `logo_thumbnail.svg`, `favicon.svg`) | 🟢 Zero (new files) |
| `config/initializers/custom_branding.rb` | New File | Synchronizes `.env` branding values to `InstallationConfig` on Rails startup | 🟢 Zero (new file) |
| `theme/brand-colors.js` | New File | Modular palette mapping `n.brand`, `brand.*`, and `woot.*` | 🟢 Zero (new file) |
| `app/javascript/dashboard/assets/scss/custom-brand.scss` | New File | CSS Custom Properties (`--brand-color`, dark mode overrides) | 🟢 Zero (new file) |
| `app/javascript/packs/custom-brand.scss` | New File | Compatibility pack forwarding to stylesheet | 🟢 Zero (new file) |
| `tailwind.config.js` | Modified (2 lines) | Imports `brandColors` and spreads into Tailwind `colors` | 🟡 Minimal (2 lines churn) |
| `app/javascript/entrypoints/dashboard.js` | Modified (1 line) | Imports `custom-brand.scss` at the global Vite entry point | 🟡 Minimal (1 line churn) |

### How to Resolve Upstream Conflicts

#### 1. Conflict in `tailwind.config.js`
If upstream modifies `tailwind.config.js`:
- Look at the imports at the top: ensure `import { brandColors } from './theme/brand-colors';` is preserved alongside `import { colors } from './theme/colors';`.
- Look at the `theme.extend.colors` block: ensure `...brandColors,` remains directly below `...colors,`.
- Example resolution:
  ```javascript
  <<<<<<< HEAD
        ...colors,
        ...brandColors,
        body: slateDark.slate7,
  =======
        ...colors,
        body: slateDark.slate7,
  >>>>>>> upstream/master
  ```
  **Resolution**: Keep both upstream's additions and `...brandColors,`.

#### 2. Conflict in `app/javascript/entrypoints/dashboard.js`
If upstream modifies global imports in `dashboard.js`:
- Keep upstream's updated imports.
- Ensure `import 'dashboard/assets/scss/custom-brand.scss';` remains among the stylesheet imports.

