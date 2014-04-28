require 'padma_user'

# Application Controller for v0 API
# @url /v0
class V0::ApplicationController < ApplicationController

  APP_KEY = ENV['app_key']

  before_filter :check_app_key
  before_filter :get_account

  def current_ability
    @current_ability ||= V0::Ability.new(@account)
  end

  rescue_from CanCan::AccessDenied do |exception|
    render :text => "access denied", :status => 401
  end

  rescue_from Mongoid::Errors::DocumentNotFound do |exception|
    render text: '404 Not found', status: 404
  end

  private

  # verifies that app_key was given
  def check_app_key
    unless params[:app_key] == APP_KEY
      render :text => "wrong app key", :status => 401
    end
  end

  def valid_timezone?(zone_name)
    zone_name && !ActiveSupport::TimeZone.new(zone_name).nil?
  end

  # will set @account if params[:account_name] is found
  # will create account if it's not mapped localy (Account checks with ACCOUNTS before creating)
  # will set locale to users locale
  def get_account
    if params[:account_name]
      @account = Account.find_or_create_by(:name => params[:account_name])

      if @account

        @padma_account = Rails.cache.fetch("accountname:#{params[:account_name]}") do
          PadmaAccount.find(params[:account_name])
        end

        # set timezone
        if @padma_account && valid_timezone?(@padma_account.timezone)
          Time.zone = @padma_account.timezone
        end

        if params[:username]
          @user = Rails.cache.fetch("username:#{params[:username]}") do
            PadmaUser.find(params[:username])
          end

          # set locale
          if @user
            I18n.locale = @user.try :locale
            # TODO: check account with user
          end
        end
      else
        render :json => "Not Found".to_json, :status => 404
      end
    end
  end
end
