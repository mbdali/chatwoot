# Raqmi Connect fork: what differs from upstream Chatwoot

`develop` tracks upstream (`chatwoot/chatwoot`) untouched; `master` is upstream plus this fork. This page is
the checklist for merging a new upstream release into `master`.

## Merging upstream

1. `git fetch upstream --tags`, then fast-forward `develop` to the release tag.
2. Merge the **release tag** (not upstream `develop`) into `master`, one release at a time.
3. Resolve conflicts. Only the files in "Upstream files we still edit" can conflict.
4. Re-check every row of "Behaviour added by prepend": the upstream method it relies on must still exist with
   the same name and arguments. A rename does not conflict, it silently disables the override, which is why
   the fork specs must run.
5. Run the fork specs (`spec/**/*_raqmi_connect_spec.rb`) and the upstream specs for the classes they prepend to.

## Behaviour added by prepend (no upstream file edited)

All wired in `config/initializers/raqmi_connect.rb`. Each module overrides with `prepend` + `super`.
Not the `custom/` extension folder: `ChatwootApp.extensions` loads `enterprise` with it and ignores
`DISABLE_ENTERPRISE`.

| Module | Prepended to | Relies on upstream | Why |
|---|---|---|---|
| `RaqmiConnect::WhatsappDispatchMarker` | `Channel::Whatsapp` | `send_message(phone, message)`, `send_template(phone, info, message)`, `send_contact_info_request(identifier, message)` being the only paths to Meta | Commits `dispatch_started_at` under a row lock just before the HTTP call; refuses a message that may already have been sent |
| `RaqmiConnect::WhatsappDispatchFailure` | `Whatsapp::SendOnWhatsappService` | `perform` | Records every dispatch exception as `DISPATCH_NOT_SENT:` / `DISPATCH_UNKNOWN:` instead of letting Sidekiq retry (a second paid message) |
| `RaqmiConnect::SendReplyJobDispatchFailure` | `SendReplyJob` | `arguments.first` is the message (or its id) | `discard_on` so a WhatsApp send is never retried; other channels re-raise and keep upstream retries |
| `RaqmiConnect::WhatsappProviderErrorClassification` | `Whatsapp::Providers::BaseService` | private `handle_error(response, message)` | Meta 5xx is `DISPATCH_UNKNOWN: HTTP <code>`, never a plain (resendable) failure |
| `RaqmiConnect::MessageRetryGuard` | `Api::V1::Accounts::Conversations::MessagesController` | private `claim_message_retry`, `clear_source_id`, `message` | Dashboard Retry refuses ERP messages and `DISPATCH_UNKNOWN`; clears the marker on an allowed retry |
| `RaqmiConnect::WhatsappIncomingReaction` | `Whatsapp::IncomingMessageBaseService` | `perform`, `messages_data`, `message_type`, `inbox`, `set_contact`, `lock_message_source_id!` | Intercepts incoming `type: reaction` webhooks, parses emoji additions/removals, and persists to `content_attributes['reactions']` under a row lock |
| `RaqmiConnect::WhatsappChannelReactions` | `Channel::Whatsapp` | `provider_service` | Delegates `send_reaction(phone, target_source_id, emoji)` to provider service |
| `RaqmiConnect::WhatsappCloudReactions` | `Whatsapp::Providers::WhatsappCloudService` | `phone_id_path`, `api_headers`, `recipient_params` | Dispatches emoji reactions and removals (`emoji: ""`) to Meta WhatsApp Cloud API |
| `RaqmiConnect::ChatwootHubSilence` | `ChatwootHub.singleton_class` | `sync_with_hub`, `register_instance`, `emit_event`, `send_push`, `support_config` | Completely silences all telemetry, registration, and version-check pings to `hub.2.chatwoot.com` |
| `RaqmiConnect::AccountCustomRoles` | `Account` | `has_many :custom_roles` | Associates custom roles with an account |
| `RaqmiConnect::AccountUserCustomRole` | `AccountUser` | `role`, `agent?`, `administrator?`, `permissions` | Resolves permissions array for custom-role agents |
| `RaqmiConnect::AgentsControllerCustomRole` | `Api::V1::Accounts::AgentsController` | `create`, `update`, `@agent`, `User#current_account_user` | Assigns and clears `custom_role_id` on agent create/update |
| `RaqmiConnect::ConversationPolicyCustomRole` | `ConversationPolicy` | `show?`, private `agent_can_view_conversation?`, `assigned_to_user?`, `participant?` | Enforces conversation permissions (`conversation_manage`, `conversation_unassigned_manage`, `conversation_participating_manage`) |
| `RaqmiConnect::PermissionFilterCustomRole` | `Conversations::PermissionFilterService` | `perform`, `user`, `account`, private `account_user` | Filters conversation lists and search according to custom role permissions |
| `RaqmiConnect::ContactPolicyCustomRole` | `ContactPolicy` | `index?`, `active?`, `search?`, `filter?`, `show?`, `create?`, `update?`, `avatar?`, `contactable_inboxes?`, `destroy_custom_attributes?` | Restricts contacts access without `contact_manage` |
| `RaqmiConnect::ReportPolicyCustomRole` | `ReportPolicy` | `view?` | Grants report view access with `report_manage` |
| `RaqmiConnect::CsatSurveyResponsePolicyCustomRole` | `CsatSurveyResponsePolicy` | `index?`, `metrics?`, `download?` | Grants CSAT survey access with `report_manage` |
| `RaqmiConnect::HelpCenterPolicyCustomRole` | `PortalPolicy`, `ArticlePolicy`, `CategoryPolicy` | `index?`, `show?`, `create?`, `update?`, `edit?`, `destroy?`, `reorder?`, `logo?`, `send_instructions?`, `ssl_status?` | Manages Help Center access with `knowledge_base_manage` |
| `RaqmiConnect::AccountDashboard` | `AccountDashboard` | `attribute_types`, `show_page_attributes`, `form_attributes`, `permitted_attributes` | Exposes features and limits management tabs and fields in Super Admin without Enterprise |

Constants defined when `enterprise/` is absent: `::CustomRole` (`RaqmiConnect::CustomRole`), `::CustomRolePolicy` (`RaqmiConnect::CustomRolePolicy`), and `Api::V1::Accounts::CustomRolesController` (`RaqmiConnect::CustomRolesController`).

Shared rules: `RaqmiConnect::WhatsappDispatch`. Strings: `config/locales/raqmi_connect.en.yml`.
The ERP contract (marker, prefixes, retry rule) is in `docs/api-integration-guide.md` §5.
The production Docker build and deployment guide is in `docs/raqmiconnect-deployment.md`.

## Fork-owned files (new, never conflict)

`app/**/raqmi_connect/`, `spec/**/*_raqmi_connect_spec.rb`, `config/initializers/raqmi_connect.rb`,
`config/initializers/custom_branding.rb`, `config/locales/raqmi_connect.en.yml`,
`lib/custom_exceptions/message_retry_error.rb`, `lib/custom_exceptions/whatsapp_reaction_error.rb`,
`lib/tasks/raqmi_connect.rake`, `app/views/api/v1/models/_account_user.json.jbuilder`,
`app/views/raqmi_connect/custom_roles/`, `app/fields/account_features_field.rb`,
`app/fields/account_limits_field.rb`, `app/views/fields/account_features_field/`,
`app/views/fields/account_limits_field/`, the PDF viewer, message reactions (`MessageReactions.vue`, `QuickReactionPicker.vue`),
messages report (`MessagesReport.vue`, `messageReports.js`), conversation search components,
brand assets under `public/custom-brand/`, `public/brand-assets/`, and `docs/`.

## Upstream files we still edit (can conflict on merge)

Frontend, branding, and minimal view guards; Ruby behaviour lives in prepended modules above.

- `app/javascript/dashboard/assets/scss/_next-colors.scss`, `_woot.scss`: brand colours
- `app/javascript/dashboard/components-next/message/bubbles/File.vue`, `chips/File.vue`: PDF preview
- `app/javascript/dashboard/components-next/message/Message.vue`: reaction badges and hover reaction trigger
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: Messages report link in navigation
- `app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js`: Messages report route definition
- `app/javascript/dashboard/routes/dashboard/settings/customRoles/customRole.routes.js`: community installation type for custom roles
- `app/views/api/v1/models/_agent.json.jbuilder`, `app/views/api/v1/models/_user.json.jbuilder`: custom role reflection guards
- `app/javascript/dashboard/components/ChatList.vue`, `i18n/locale/en/chatlist.json`: in-place search
- `app/javascript/dashboard/i18n/locale/en/conversation.json`, `app/javascript/entrypoints/dashboard.js`
- `app/javascript/dashboard/i18n/locale/en/report.json`: `MESSAGES_REPORT` copy
- `app/javascript/dashboard/i18n/locale/en/settings.json`: `SIDEBAR.REPORTS_MESSAGES` copy
- `app/helpers/super_admin/navigation_helper.rb`, `app/views/layouts/super_admin/application.html.erb`,
  `app/views/super_admin/application/_brand.html.erb`, `_standalone.html.erb`: super-admin branding
- `tailwind.config.js`, `docker/Dockerfile`, `.gitignore`, `.dockerignore`, `public/manifest.json`
- Replaced icons in `public/` (favicons, apple/android/ms icons, `brand-assets/logo*.svg`): on conflict,
  keep ours.

Regenerate this list with:
`git diff --name-status $(git merge-base master develop) master | grep '^M'`
