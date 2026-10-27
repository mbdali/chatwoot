# Raqmi Connect: Production Deployment Guide

This document outlines the end-to-end procedure for building, packaging, transferring, and deploying custom **Raqmi Connect** production images to the production server using Docker and Docker Compose.

---

## 1. Prerequisites

- **Workstation / Build Machine**:
  - Docker & Docker Buildx installed.
  - Repository branch `master` is clean and up to date.
  - Fork test suite and frontend unit tests are passing.
- **Production Server**:
  - Docker & Docker Compose v2 installed.
  - SSH access with sudo / Docker daemon permissions.
  - Existing Chatwoot Docker Compose stack (e.g., PostgreSQL, Redis, Rails, Sidekiq).

---

## 2. Pre-Build Verification

Always ensure tests and linters pass before building the production image:

```bash
# 1. Run the fork test suite (Ruby)
docker run --rm --network chatwoot_default -v $(pwd):/app -w /app chatwoot-test:latest \
  bundle exec rspec spec/**/*_raqmi_connect_spec.rb

# 2. Run the frontend unit tests
pnpm test app/javascript/dashboard/routes/dashboard/settings/reports/specs/MessagesReport.spec.js \
  app/javascript/dashboard/api/raqmi_connect/specs/messageReports.spec.js \
  app/javascript/dashboard/components-next/message/specs/MessageReactions.spec.js \
  app/javascript/dashboard/components-next/message/specs/QuickReactionPicker.spec.js
```

---

## 3. Step-by-Step Deployment Workflow

### Step 1: Build the Custom Production Image

Build the production image using the project's production Dockerfile (`docker/Dockerfile`).

> [!IMPORTANT]
> If building on an Apple Silicon (M1/M2/M3/M4) Mac or ARM workstation, explicitly specify `--platform linux/amd64` to match standard x86 production servers.

```bash
cd /path/to/chatwoot

docker build \
  --platform linux/amd64 \
  -t raqmi-connect:latest \
  -f docker/Dockerfile .
```

---

### Step 2: Tar and Compress the Docker Image

Piping `docker save` through `gzip` compresses the image from ~2–3 GB down to ~600–800 MB, significantly reducing transfer time. 

> [!TIP]
> Save the compressed archive to `/tmp/` (or outside the repository) to avoid accidentally committing or nesting large archives in the project directory:

```bash
docker save raqmi-connect:latest | gzip > /tmp/raqmi-connect-latest.tar.gz
```

Verify the archive was generated and check its size:
```bash
ls -lh /tmp/raqmi-connect-latest.tar.gz
```

---

### Step 3: Transfer Image to Production Server

Use `rsync` (recommended for progress and resume support) or `scp` to transfer the archive:

```bash
# Using rsync (recommended)
rsync -avP --partial /tmp/raqmi-connect-latest.tar.gz USER@YOUR_SERVER_IP:/tmp/

# Or using standard scp
scp /tmp/raqmi-connect-latest.tar.gz USER@YOUR_SERVER_IP:/tmp/
```

---

### Step 4: Load Docker Image on Production Server

SSH into the production server and load the archive into the local Docker daemon:

```bash
ssh USER@YOUR_SERVER_IP

# Load the compressed docker image
docker load -i /tmp/raqmi-connect-latest.tar.gz

# Confirm the image is loaded
docker images | grep raqmi-connect
```

---

### Step 5: Retag and Apply to Production Services

Depending on your production Docker Compose setup:

#### Option A: Retag as `chatwoot/chatwoot:latest` (Default Setup)
If your `docker-compose.production.yaml` references `chatwoot/chatwoot:latest`, retag the image:

```bash
docker tag raqmi-connect:latest chatwoot/chatwoot:latest
```

#### Option B: Dedicated Image Tag
If your compose file or `.env` specifies a custom image tag (e.g., `image: raqmi-connect:latest`), proceed directly to container restart.

#### Restart Services:
Navigate to your production deployment directory and recreate the application containers:

```bash
cd /path/to/production/deployment

# Recreate and restart only rails and sidekiq without restarting postgres/redis
docker compose -f docker-compose.production.yaml up -d --no-deps rails sidekiq
```

*(If you use standard `docker-compose.yaml` or a unified compose file, use `docker compose up -d --no-deps rails sidekiq`)*

---

### Step 6: Verification & Health Checks

1. **Inspect Rails server logs:**
   ```bash
   docker compose logs -f --tail=100 rails
   ```
   Ensure Rails boots cleanly without initialization errors.

2. **Inspect Sidekiq worker logs:**
   ```bash
   docker compose logs -f --tail=100 sidekiq
   ```

3. **Verify running containers:**
   ```bash
   docker compose ps
   ```

4. **Verify Application Endpoints:**
   - Log into Dashboard: Navigate to **Reports** → **Messages** to confirm the Messages Report is live.
   - Send a test WhatsApp reaction to verify webhook and outbound Cloud API dispatch.

---

### Step 7: Post-Deployment Cleanup

Remove the temporary archive to free disk space on the server:

```bash
rm /tmp/raqmi-connect-latest.tar.gz
```

---

## 4. Rollback Procedure

If any issue arises after deploying:

1. Re-tag the previously known good image or pull upstream:
   ```bash
   docker tag raqmi-connect:previous-good-tag chatwoot/chatwoot:latest
   ```
2. Restart the containers:
   ```bash
   docker compose -f docker-compose.production.yaml up -d --no-deps rails sidekiq
   ```
