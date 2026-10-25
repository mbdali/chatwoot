# Raqmi Connect fork behaviour, kept out of upstream files so an upstream merge cannot conflict with it.
# Each module overrides by `prepend` + `super`; docs/FORK.md lists them and what each one relies on.
#
# Not the `custom/` extension folder: ChatwootApp.extensions loads `enterprise` with it and ignores
# DISABLE_ENTERPRISE.
Rails.application.config.to_prepare do
  Channel::Whatsapp.prepend(RaqmiConnect::WhatsappDispatchMarker)
  Whatsapp::SendOnWhatsappService.prepend(RaqmiConnect::WhatsappDispatchFailure)
  Whatsapp::Providers::BaseService.prepend(RaqmiConnect::WhatsappProviderErrorClassification)
  SendReplyJob.prepend(RaqmiConnect::SendReplyJobDispatchFailure)
  Api::V1::Accounts::Conversations::MessagesController.prepend(RaqmiConnect::MessageRetryGuard)
end
