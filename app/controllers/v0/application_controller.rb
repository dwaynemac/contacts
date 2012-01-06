require 'padma_user'

# Application Controller for v0 API
class V0::ApplicationController < ApplicationController

  APP_KEY = "844d8c2d20a9cf9e97086df94f01e7bdd3d9afaa716055315706f2e31f40dc097c632af53e74ce3d5a1f23811b4e32e7a1e2b7fa5c128c8b28f1fc6e5a392015"

  before_filter :check_app_key
  before_filter :get_account

  def current_ability
    @current_ability ||= V0::Ability.new(@account)
  end

  rescue_from CanCan::AccessDenied do |exception|
    render :text => "access denied", :status => 401
  end

  private

  # verifies that app_key was given
  def check_app_key
    unless params[:app_key] == APP_KEY
      render :text => "wrong app key", :status => 401
    end
  end

  # will set @account if params[:account_name] is found
  # will create account if it's not mapped localy (Account checks with ACCOUNTS before creating)
  # will set locale to users locale
  def get_account
    if params[:account_name]
      @account = Account.find_or_create_by(:name => params[:account_name])

      if @account.id.nil?
        render :json => "Not Found".to_json, :status => 404
      elsif params[:user_id]
        @user = PadmaUser.find(params[:user_id])

        # set locale
        I18n.locale = @user.try :locale
        # TODO: check account with user
    end
    end
  end
end