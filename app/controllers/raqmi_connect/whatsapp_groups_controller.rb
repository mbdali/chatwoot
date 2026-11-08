# frozen_string_literal: true

# Raqmi Connect fork: API controller for managing WhatsApp groups via Meta Cloud API.
class RaqmiConnect::WhatsappGroupsController < Api::V1::Accounts::BaseController
  before_action :set_inbox

  rescue_from CustomExceptions::WhatsappGroupError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    return render_subject_blank_error if subject_param.blank?

    service = RaqmiConnect::WhatsappGroupService.new(inbox: @inbox)
    group_data = service.create_group(
      subject: subject_param,
      description: params[:description]
    )

    invited = maybe_send_invite(service, group_data)
    render json: group_data.merge(invited: invited), status: :created
  end

  private

  def subject_param
    @subject_param ||= params[:subject].to_s.strip
  end

  def render_subject_blank_error
    render json: { error: 'Group subject cannot be blank.' }, status: :unprocessable_entity
  end

  def maybe_send_invite(service, group_data)
    return false unless ActiveModel::Type::Boolean.new.cast(params[:auto_invite]) && params[:conversation_id].present?

    target_conversation = current_account.conversations.find_by(id: params[:conversation_id])
    return false if target_conversation.blank? || group_data[:invite_link].blank?

    service.send_invite_to_conversation(
      target_conversation,
      invite_link: group_data[:invite_link],
      subject: group_data[:subject]
    )
    true
  end

  def set_inbox
    @inbox = current_account.inboxes.find(params[:inbox_id])
  end
end
