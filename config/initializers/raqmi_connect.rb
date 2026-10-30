# frozen_string_literal: true

# Raqmi Connect fork behaviour, kept out of upstream files so an upstream merge cannot conflict with it.
# Each module overrides by `prepend` + `super`; docs/FORK.md lists them and what each one relies on.
#
# Not the `custom/` extension folder: ChatwootApp.extensions loads `enterprise` with it and ignores
# DISABLE_ENTERPRISE.

module RaqmiConnect
  def self.custom_roles?
    !Rails.root.join('enterprise').exist?
  end
end

if Rails.root.join('enterprise').exist? && ActiveModel::Type::Boolean.new.cast(ENV.fetch('DISABLE_ENTERPRISE', false))
  raise 'DISABLE_ENTERPRISE still loads enterprise/ code; build without the enterprise/ directory instead'
end

Rails.application.config.to_prepare do
  ChatwootHub.singleton_class.prepend(RaqmiConnect::ChatwootHubSilence)
  Channel::Whatsapp.prepend(RaqmiConnect::WhatsappDispatchMarker)
  Channel::Whatsapp.prepend(RaqmiConnect::WhatsappChannelReactions)
  Whatsapp::IncomingMessageBaseService.prepend(RaqmiConnect::WhatsappIncomingReaction)
  Whatsapp::Providers::WhatsappCloudService.prepend(RaqmiConnect::WhatsappCloudReactions)
  Whatsapp::SendOnWhatsappService.prepend(RaqmiConnect::WhatsappDispatchFailure)
  Whatsapp::Providers::BaseService.prepend(RaqmiConnect::WhatsappProviderErrorClassification)
  SendReplyJob.prepend(RaqmiConnect::SendReplyJobDispatchFailure)
  Api::V1::Accounts::Conversations::MessagesController.prepend(RaqmiConnect::MessageRetryGuard)

  if RaqmiConnect.custom_roles?
    [:CustomRole, :CustomRolePolicy].each do |const_name|
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)
    end
    Object.const_set(:CustomRole, RaqmiConnect::CustomRole)
    Object.const_set(:CustomRolePolicy, RaqmiConnect::CustomRolePolicy)

    Api::V1::Accounts.send(:remove_const, :CustomRolesController) if Api::V1::Accounts.const_defined?(:CustomRolesController, false)
    Api::V1::Accounts.const_set(:CustomRolesController, RaqmiConnect::CustomRolesController)

    Account.prepend(RaqmiConnect::AccountCustomRoles)
    AccountUser.prepend(RaqmiConnect::AccountUserCustomRole)
    Api::V1::Accounts::AgentsController.prepend(RaqmiConnect::AgentsControllerCustomRole)
    ConversationPolicy.prepend(RaqmiConnect::ConversationPolicyCustomRole)
    Conversations::PermissionFilterService.prepend(RaqmiConnect::PermissionFilterCustomRole)
    ContactPolicy.prepend(RaqmiConnect::ContactPolicyCustomRole)
    ReportPolicy.prepend(RaqmiConnect::ReportPolicyCustomRole)
    CsatSurveyResponsePolicy.prepend(RaqmiConnect::CsatSurveyResponsePolicyCustomRole)
    PortalPolicy.prepend(RaqmiConnect::HelpCenterPolicyCustomRole)
    ArticlePolicy.prepend(RaqmiConnect::HelpCenterPolicyCustomRole)
    CategoryPolicy.prepend(RaqmiConnect::HelpCenterPolicyCustomRole)
    AccountDashboard.prepend(RaqmiConnect::AccountDashboard)
  else
    Rails.logger.info('[RaqmiConnect] enterprise/ present; fork custom roles inactive')
  end
end

Rails.application.config.after_initialize do
  Rails.application.routes.append do
    namespace :api, defaults: { format: 'json' } do
      namespace :v1 do
        resources :accounts, only: [] do
          namespace :reports do
            get :messages, to: '/raqmi_connect/message_reports#show'
          end
          resources :conversations, only: [] do
            scope module: :conversations do
              resources :messages, only: [] do
                member do
                  post :reaction, controller: '/raqmi_connect/message_reactions', action: :create
                  delete :reaction, controller: '/raqmi_connect/message_reactions', action: :destroy
                end
              end
            end
          end
        end
      end
    end
  end
end
