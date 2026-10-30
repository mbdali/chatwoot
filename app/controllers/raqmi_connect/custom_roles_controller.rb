# frozen_string_literal: true

# Raqmi Connect fork: MIT-compliant custom roles controller (docs/FORK.md).
# Bound to Api::V1::Accounts::CustomRolesController when enterprise/ is absent.
class RaqmiConnect::CustomRolesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_custom_role, only: [:show, :update, :destroy]

  def index
    @custom_roles = Current.account.custom_roles
    render template: 'raqmi_connect/custom_roles/index'
  end

  def show
    render template: 'raqmi_connect/custom_roles/show'
  end

  def create
    @custom_role = Current.account.custom_roles.create!(custom_role_params)
    render template: 'raqmi_connect/custom_roles/create'
  end

  def update
    @custom_role.update!(custom_role_params)
    render template: 'raqmi_connect/custom_roles/update'
  end

  def destroy
    @custom_role.destroy!
    head :ok
  end

  private

  def fetch_custom_role
    @custom_role = Current.account.custom_roles.find(params[:id])
  end

  def custom_role_params
    params.require(:custom_role).permit(:name, :description, permissions: [])
  end
end
