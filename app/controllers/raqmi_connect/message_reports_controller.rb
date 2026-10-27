# frozen_string_literal: true

# Raqmi Connect fork: controller for aggregate message reports per inbox and across inboxes.
# Delivers incoming/outgoing volume, delivery rates, error rates, and grouped timeseries charts.
class RaqmiConnect::MessageReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    builder = RaqmiConnect::MessageReportsBuilder.new(Current.account, permitted_params)
    render json: builder.build
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def permitted_params
    params.permit(:since, :until, :inbox_id, :group_by, :outgoing_group_by, :timezone_offset)
  end
end
