# Complaints module inside Raqmi Connect

**Status:** Proposal for review. No code written. Decisions C-D1…C-D12 (§4) must be settled before C1.

**Review context:** this is one of two options for running WhatsApp and complaints management as **one app**:

| Option | Where | Plan |
|---|---|---|
| **A**: WhatsApp into Raqmi Resolve | RaqmiResolve repo | `docs/whatsapp-channel-shared-inbox-plan.md` (W track): rebuild a Chatwoot-style inbox in .NET |
| **B**: complaints into Raqmi Connect | this repo | this document: port Resolve's complaints domain into the Chatwoot fork, retire Resolve |

§10 compares the two side by side.

---

## 1. What this is

Raqmi Connect (this fork) already provides the shared inbox: WhatsApp Cloud API with the fork's dispatch
safety (`docs/FORK.md`), contacts, conversations, agents, teams, labels, canned responses, macros,
automations, reports and real time. Option B adds Raqmi Resolve's complaints system of record to it as a
fork-owned module, so customers get one product, one login, one deployment.

What must come across from Resolve (ASP.NET Core 10, about 33k lines of app code, 19 xUnit test classes):

| Resolve capability | Source in RaqmiResolve repo |
|---|---|
| Complaint record, 8-state lifecycle, reference sequences | `sql/04_complaints.sql`, `Services/ComplaintStateMachine.cs`, `Services/ComplaintService.cs` |
| Classification: types, subjects, priorities, statuses (labels only), root causes, departments, service centres, services | `sql/02_master_data.sql`, `sql/03_complaint_config.sql`, `Pages/Config/*` |
| Business-hours SLA with holidays and DST rules | `Services/Sla/*`, `BusinessHoursCalculatorTests.cs` (19 cases) |
| Fine-grained permissions (`complaints.view/create/edit/assign/resolve/close/reopen/reject/notes/reply`, attachments, legal hold, config, reports, audit) | `Services/Auth/Permissions.cs` |
| Passwordless bilingual (en/ar) customer portal: intake, track, email OTP return access, bearer `/c/{token}` links | `Services/Portal/*`, `Pages/Portal/*`, `sql/05_portal.sql` |
| Evidence attachments, AV scan, retention policies, sweeper, legal hold | `Services/Files/*`, `Services/Retention/*`, `Services/Jobs/*` |
| Notification templates (en/ar) with revisions, outbox drain | `Services/Notifications/*`, `sql/06_notification_templates.sql` |
| Reports and transaction volumes | `Pages/Reports/*`, `sql/08_reports_volumes_permission.sql` |
| Terminology overrides (tenant wording as data) | `Services/Localization/Terminology*`, `sql/07_ui_terminology.sql` |
| ERP invoice lookup over HTTP | `Services/Erp/ErpInvoiceLookupClient.cs` (`GET api/v1/invoices/context/{reference}`) |
| Offline signed licence (`.rrl`, ECDSA) | `RaqmiResolve.Licensing`, `Services/Licensing/*` |

What Resolve has that Chatwoot already covers, so it is **not** ported: staff users and login, setup wizard,
installation home and encrypted config store (Chatwoot uses env + `installation_configs`), branding
(this fork's `custom_branding`), email transport, background job host (Sidekiq), canned responses (Chatwoot's
own, if one set serves both chat and complaints; see C-D11).

---

## 2. Fork rules this module follows

The module is built the way this fork already builds WhatsApp dispatch safety (`docs/FORK.md`), so the
upstream merge procedure does not change:

- **Ruby lives in `custom/`**, Chatwoot's extension slot (`docs/FORK.md`, "The `custom/` extension
  folder"): `custom/app/models/`, `custom/app/controllers/` (and `api/v1/accounts/`), `custom/app/services/`,
  `custom/app/jobs/`, `custom/app/policies/`, `custom/app/views/`, `custom/lib/`. New classes are namespaced
  `RaqmiConnect::` (e.g. `custom/app/models/raqmi_connect/complaint.rb`).
- **Vue lives in fork-owned folders** under `app/javascript/dashboard/routes/dashboard/raqmi_connect/`;
  specs are `spec/**/*_raqmi_connect_spec.rb`.
- **Behaviour on upstream classes**, in this order of preference:
  1. a `Custom::<Name>` module picked up by the upstream class's own `prepend_mod_with` / `include_mod_with`
     hook (e.g. `Custom::Conversation` to add `has_many :complaints`);
  2. where upstream has no hook, `prepend` + `super` from `config/initializers/raqmi_connect.rb`, as the
     WhatsApp dispatch modules already do.

  Either way, one row in `FORK.md` naming the upstream methods relied on.
- **Consequence accepted with `custom/`:** `enterprise/` is always loaded and `DISABLE_ENTERPRISE` stops
  working (`lib/chatwoot_app.rb`). Nothing in this repo sets it today.
- **Do not port from or depend on `enterprise/`.** SLA policies (`sla_policy.rb`, `applied_sla.rb`), custom
  roles and audit logs live there under Chatwoot's commercial licence. The complaints SLA, permissions and
  audit are this module's own code, designed from Resolve, not from `enterprise/`.
- **Upstream conventions** (`AGENTS.md`): ActiveRecord only, no raw SQL; migrations via
  `rails g migration`; Tailwind only; `<script setup>` Composition API; no bare strings in templates.
- **Routes:** fork routes in a fork-owned file drawn from `config/routes.rb` with one `draw` line (one-line
  upstream edit), or appended from the initializer. Decide in C1; either way, one row in `FORK.md`.
- **Cron:** fork jobs are loaded into sidekiq-cron from the fork initializer with their own `source:`, never
  added to upstream `config/schedule.yml` (upstream's loader only prunes `source: 'schedule'` entries).

Upstream files this module **will** have to edit (each becomes a row in `FORK.md`'s conflict list):

| File | Why |
|---|---|
| `config/application.rb` | load `custom/app/**`, `custom/lib`, `custom/app/views`; upstream autoloads only `enterprise/` |
| `config/routes.rb` | one `draw(:raqmi_connect)` line (if that route option is chosen) |
| `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` | mount the complaints route tree |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` | "Complaints" menu entry |
| `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` | complaints panel in the conversation sidebar |
| `app/javascript/dashboard/i18n/locale/{en,ar}/index.js` | import the fork's `raqmiComplaints.json` |

Six small edits. Everything else is new files, plus `db/schema.rb` (see §11). That count is the measure
to protect over time.

---

## 3. Stack mapping

| Concern | Resolve | In Raqmi Connect |
|---|---|---|
| Data access | Dapper, raw idempotent SQL files | ActiveRecord models + migrations |
| Tenancy | One database per customer, no tenant column ever | `account_id` on every table, scoped through `Current.account` like upstream (C-D1) |
| Staff UI | Razor Pages, Bootstrap 5, RTL | Vue 3 SPA screens inside the dashboard, Tailwind, Chatwoot's RTL |
| Customer portal | Razor Pages `/c`, `/portal/*` | Fork ERB views under a public controller, no SPA (C-D4) |
| Jobs | Hosted services + `job_leases` | Sidekiq jobs + sidekiq-cron; Sidekiq's uniqueness replaces leases |
| Files | `{home}/storage/`, own `IFileStorage` | ActiveStorage (same backend Chatwoot already uses, local or S3) |
| Real time | none | ActionCable: complaint updates broadcast on the account channel |
| Clock | injected `IClock`, `DateTime.Now` banned by analyzer | `Time.current` only; specs freeze time with `travel_to`; RuboCop `Rails/TimeZone` enforced |
| Tests | xUnit, frozen clock | RSpec, `*_raqmi_connect_spec.rb` |

---

## 4. Decisions to settle before C1

Each has a recommendation. Settled decisions move into the body of the plan.

| # | Decision | Recommendation |
|---|---|---|
| **C-D1** | Tenancy. Resolve's rule is one database per customer with no scope column; Chatwoot is multi-account. | Follow Chatwoot: every complaints table has `account_id`, all access goes through account-scoped associations (`Current.account.raqmi_connect_complaints`) and Pundit policies, like upstream. Deploy **one installation per customer** anyway, as now. The scope column is then the same mechanism upstream already relies on for conversations, not a half-honoured predicate. |
| **C-D2** | Table names. | Namespace them: models `RaqmiConnect::Complaint` etc. with `table_name_prefix 'raqmi_connect_'`. Upstream can never add a colliding `complaints` table. |
| **C-D3** | Permissions. Chatwoot core has only `administrator` / `agent`; custom roles are `enterprise/`. | Own permission catalogue (port Resolve's list as-is) with fork tables `raqmi_connect_roles`, `raqmi_connect_role_permissions`, `raqmi_connect_account_user_roles` hanging off `account_users`. Administrators get all. An agent with no complaints role still gets `inbox.complaints.raise` (C-D5). |
| **C-D4** | Customer portal. | Keep it: not every complainant arrives over WhatsApp, and regulators expect a web channel. Server-rendered ERB, en/ar with RTL, port of Resolve's intake, track, OTP return access and `/c/{token}` bearer links. Rate limits on Rails' `rate_limit` / Rack::Attack (already in Chatwoot). Keep Resolve's logging rule: the bearer path must never reach logs (Rails `filter_parameters` plus a path filter). |
| **C-D5** | Conversation ↔ complaint. | Complaint has optional `contact_id` and a join table to conversations. "Raise complaint" from the conversation sidebar pre-fills contact, channel and quoted messages. An agent without `complaints.view` sees only the reference and customer-facing status (carries over Resolve W-D3). |
| **C-D6** | Status notifications. | Send through the linked conversation's inbox: WhatsApp template (bilingual, one per customer-facing status) when the 24h window is closed, free text inside it; email via ActionMailer otherwise. Goes through the fork's dispatch-safe path, so a status update is never sent twice. **Never** put the `/c/{token}` bearer link in a WhatsApp message (carries over W-D6); send the reference and the OTP-gated portal link. |
| **C-D7** | Consent for business-initiated WhatsApp. | Opt-in captured at portal intake; a complaint raised from a customer-started WhatsApp conversation records that message id as the opt-in evidence. No opt-in, email only. Opt-out checked at send time. |
| **C-D8** | SLA calendar. | Own calendar model (intervals + holidays + IANA timezone), **not** `inbox.working_hours` (no holidays, per inbox not per organisation) and not enterprise SLA. Port `BusinessHoursCalculator` and its 19 test cases first; they are the spec. |
| **C-D9** | Licensing. | Decide commercially. If kept: port only the verifier to Ruby (ECDSA, same `.rrl` format, public key embedded in the code, never read from disk or uploaded), so the existing .NET `RaqmiResolve.LicenceGenerator` keeps issuing. Move the generator to its own private repo when Resolve is archived. |
| **C-D10** | Terminology overrides. | Port: tenant wording as data overriding i18n keys in the complaints screens and portal only. Do not try to override upstream Chatwoot strings. |
| **C-D11** | Canned responses. | Reuse Chatwoot's `canned_responses` for replies to customers; Resolve's complaint-specific placeholders (reference, status, due date) become a fork renderer applied on insert. |
| **C-D12** | Existing Resolve installations. | If any installation holds live data, C8 is mandatory: a one-off Ruby importer reading the Resolve database (read-only connection) into the new tables, keeping references, history, attachments and audit. If none, skip C8. |

---

## 5. Data model

All tables prefixed `raqmi_connect_`, all with `account_id`, timestamps in UTC. Ported from Resolve's SQL;
column-level detail is settled in C1 against the Resolve files named.

| Table | From Resolve | Notes |
|---|---|---|
| `complaints` | `04_complaints.sql` `complaints` | reference, type, subject, priority, status (8 fixed codes), department, assignee (`users`), `contact_id`, channel, SLA due/met fields, legal hold flag |
| `complaint_status_history` | same | every transition with actor and reason; SLA events stamped here |
| `complaint_messages` | same | internal notes and customer-visible replies; `source` includes `whatsapp`, `portal`, `email`, `staff` |
| `complaint_attachments` | same | ActiveStorage attachment + scan state + retention class |
| `complaint_actions`, `complaint_links`, `complaint_external_references` | same | external reference holds ERP invoice context |
| `complaint_conversations` | new | join to Chatwoot `conversations` (C-D5) |
| `complaint_types`, `_subjects`, `_priorities`, `_statuses`, `_root_causes`, `_sequences` | `03_complaint_config.sql` | statuses carry label/colour only; the machine stays in code |
| `departments`, `service_centres`, `services`, `transaction_volumes` | `02_master_data.sql` | departments stay separate from Chatwoot teams (chat routing and complaint routing change for different reasons) |
| `working_calendars`, `_intervals`, `_holidays` | `02_master_data.sql` | C-D8 |
| `roles`, `role_permissions`, `account_user_roles` | `01_organisation_identity.sql` | C-D3 |
| `audit_events` | `01_organisation_identity.sql` | complaints audit; not `enterprise/` audit logs |
| `customer_identities`, `complaint_identity_links`, `customer_otp_challenges`, `public_intake_links`, `public_submission_ledger` | `05_portal.sql` | portal (C-D4); identity links to Chatwoot `contacts` where the email/phone matches |
| `notification_templates`, `_revisions`, `notification_outbox` | `05_portal.sql`, `06_notification_templates.sql` | outbox per channel (email, whatsapp) |
| `retention_policies`, `retention_runs` | `05_portal.sql` | sweeper runs as a Sidekiq cron job |
| `ui_terms`, `ui_label_overrides` | `07_ui_terminology.sql` | C-D10 |
| `licence_records` | `09_licensing.sql` | only if C-D9 keeps licensing |

Not ported: `organisation` (Chatwoot `accounts`), `staff_users`, `staff_login_history` (Chatwoot users and
sessions), `brand_assets` (fork branding), `rate_limit_counters` (Rack::Attack), `job_leases` (Sidekiq).

The state machine (`new → assigned → in_progress → pending_customer → resolved → closed`, `→ rejected`,
`resolved/closed/rejected → reopened`) is a plain Ruby class with the same transition table as
`ComplaintStateMachine.cs`, and `ComplaintStateMachineTests.cs` ported as its spec.

---

## 6. Staff UI

Vue screens under `routes/dashboard/raqmi_connect/complaints/`, using `components-next` and Tailwind:

- **Complaints list:** filters (status, priority, department, assignee, SLA breached/at risk, date), saved
  views, bulk assign.
- **Complaint detail:** header with status actions allowed by the machine and the user's permissions, SLA
  clock, timeline (messages, notes, status history), attachments with scan state, actions, linked
  conversations, ERP context.
- **New complaint:** staff intake form.
- **Conversation sidebar panel:** linked complaints with customer-facing status, "Raise complaint".
- **Settings → Complaints:** classification, departments, calendars, priorities and SLA targets, templates,
  portal, retention, terminology, roles and permissions, licence.
- **Reports → Complaints:** volumes, ageing, SLA compliance, root causes, per department/service.

Arabic: Chatwoot already ships `ar` and RTL; the fork adds `raqmiComplaints.json` for `en` and `ar`.

---

## 7. Customer portal

Public, server-rendered ERB under the fork's controllers, own layout carrying the fork's branding:

- `/c/new`: intake (rate-limited, form stamp against replay, attachment upload with scan).
- `/c/{token}`: bearer link to one complaint (sent by email only).
- `/portal/access` → email OTP → `/portal/mine`: all of a customer's complaints.
- Reply, upload more evidence, accept (close) or reopen a resolved complaint.

Ported specs: `PortalTokenTests`, `FormStampTests`, `PortalLocalizationTests`, `PortalPasswordTests`,
`IntakeAttachmentTests`.

---

## 8. Background jobs

All Sidekiq jobs in `custom/app/jobs/raqmi_connect/`, scheduled from the fork initializer (§2):

| Job | Replaces |
|---|---|
| `SlaTickJob`: stamps at-risk / breached, notifies | SLA checks in `ComplaintService` |
| `NotificationDrainJob`: email + WhatsApp outbox | `OutboxDrainService` |
| `AttachmentScanJob` | `AttachmentScanService` |
| `RetentionSweepJob`: honours legal hold | `RetentionSweeperService` |

---

## 9. Delivery phases

Rough estimates for one developer comfortable in Rails and Vue. They exclude Meta template approval lead
time (start in C0) and any learning curve if the team is .NET-first.

| Phase | Scope | Estimate |
|---|---|---|
| **C0** | Settle C-D1…C-D12; submit status templates (en/ar) to Meta; confirm whether any live Resolve installation exists (C-D12) | — |
| **C1** | `custom/` load-path block in `config/application.rb`; models and migrations (§5), state machine, SLA calculator + calendars, permission catalogue and policies, audit; specs ported from Resolve first (`BusinessHoursCalculatorTests`, `ComplaintStateMachineTests`, `PermissionCatalogueTests`) | 3–4 weeks |
| **C2** | Staff UI: list, detail, new, settings screens; the frontend upstream edits (§2); `FORK.md` rows | 4–5 weeks |
| **C3** | Conversation bridge: sidebar panel, "Raise complaint", status notifications over WhatsApp/email through the dispatch-safe path, consent | 1.5–2 weeks |
| **C4** | Customer portal en/ar: intake, bearer links, OTP, replies, accept/reopen | 3 weeks |
| **C5** | Attachments: ActiveStorage, scan, retention policies, sweeper, legal hold | 1.5–2 weeks |
| **C6** | Reports and transaction volumes; terminology overrides | 2 weeks |
| **C7** | ERP invoice lookup client; licence verifier (if C-D9 keeps it) | 1 week |
| **C8** | Importer from Resolve and cut-over (only if C-D12 finds live data) | 1–2 weeks |

Total: roughly **17–21 weeks** (16–19 without C8).

---

## 10. Option A vs Option B

| | **A: WhatsApp into Resolve** | **B: complaints into Raqmi Connect** |
|---|---|---|
| Apps to run | One (Resolve) | One (Raqmi Connect) |
| Build effort | ~10–13 weeks (W track) | ~17–21 weeks (§9) |
| What is rewritten | Shared inbox, from scratch in .NET | Complaints domain (~33k lines), Ruby/Vue |
| WhatsApp maintenance | Ours forever: Meta API versions, template sync, media, status callbacks, edge cases | Upstream's: merged from Chatwoot releases; the fork's dispatch-safety modules stay ours |
| Inbox breadth | Only what we build (W-track scope) | Everything Chatwoot has: more channels (email, web widget, Instagram, Telegram…), macros, automations, CSAT, mobile apps |
| Complaints | Already built, tested, shipped (Phases 0–2) | Rebuilt; regression risk until specs are ported |
| Upstream merge cost | None | Per release: 6 upstream edits for complaints (§2) + `db/schema.rb` + existing fork edits; prepend and `Custom::` rows re-checked |
| Stack | .NET, same as RaqmiERP / RaqmiFlow | Rails + Vue; a second stack to keep skills in |
| Tenancy model | One database per customer, no scope column | `account_id` (C-D1) |
| Licensing | Built (`.rrl`) | Port verifier or drop (C-D9) |
| Real time | To build (SignalR + `LISTEN/NOTIFY`) | Already there (ActionCable) |
| Mobile app for agents | None | Chatwoot's mobile apps work for the inbox (not the complaints screens) |

Rule of thumb for the review: **B wins if WhatsApp is only the first of several channels**, or if the team
is willing to work in Rails long term. **A wins if WhatsApp is the only channel** and the team stays .NET:
the W track is smaller than the complaints rewrite and keeps one stack.

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| Upstream renames a method a prepend relies on; the override silently stops | Existing `FORK.md` step 4: re-check every prepend row, run fork specs on every merge |
| Upstream renames or drops a `prepend_mod_with` hook a `Custom::` module relies on; the module silently stops applying | Same as prepend rows: listed in `FORK.md`, covered by fork specs that fail if the association/method is missing |
| `db/schema.rb` conflicts on every upstream merge that adds a migration | Never hand-merge it: take upstream's, run `db:migrate` (fork migrations reapply), commit the dumped result |
| Upstream restructures the Vue sidebar or routes | Only a few edit points (§2); keep them one-liners that import fork components |
| SLA or lifecycle behaviour drifts from Resolve during the port | Port the Resolve tests before the code (C1); same cases, same expected values |
| Bearer portal links leak into logs or Meta | Path filtered from logs (C-D4); never sent over WhatsApp (C-D6) |
| Inbox agents see complaint internals | `inbox.complaints.raise` without `complaints.view`; customer-facing projection only; policy specs |
| Accidental dependency on `enterprise/` (always loaded once `custom/` exists) | Never reference `Enterprise::` classes or enterprise feature flags from fork code; a RuboCop/grep check in CI over `custom/` and fork Vue folders |
| Second stack to maintain | Accept consciously in the review (§10) |

---

## 12. What happens to Raqmi Resolve under Option B

Archived, not deleted: it remains the reference implementation for the port and the source of the tests to
port. The licence generator moves to its own private repo if licensing is kept (C-D9). Resolve's Phase 3
API (`POST /api/v1/complaints`) and the W track are not built.
