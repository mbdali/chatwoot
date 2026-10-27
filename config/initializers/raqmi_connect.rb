# Raqmi Connect fork behaviour, kept out of upstream files so an upstream merge cannot conflict with it.
# Each module overrides by `prepend` + `super`; docs/FORK.md lists them and what each one relies on.
#
# Not the `custom/` extension folder: ChatwootApp.extensions loads `enterprise` with it and ignores
# DISABLE_ENTERPRISE.
Rails.application.config.to_prepare do
  Channel::Whatsapp.prepend(RaqmiConnect::WhatsappDispatchMarker)
  Channel::Whatsapp.prepend(RaqmiConnect::WhatsappChannelReactions)
  Whatsapp::IncomingMessageBaseService.prepend(RaqmiConnect::WhatsappIncomingReaction)
  Whatsapp::Providers::WhatsappCloudService.prepend(RaqmiConnect::WhatsappCloudReactions)
  Whatsapp::SendOnWhatsappService.prepend(RaqmiConnect::WhatsappDispatchFailure)
  Whatsapp::Providers::BaseService.prepend(RaqmiConnect::WhatsappProviderErrorClassification)
  SendReplyJob.prepend(RaqmiConnect::SendReplyJobDispatchFailure)
  Api::V1::Accounts::Conversations::MessagesController.prepend(RaqmiConnect::MessageRetryGuard)
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
