require "#{Rails.root}/app/controllers/v0/concerns/contacts_scope"

##
# @restful_api v0
class V0::CalculatesController < V0::ApplicationController

  include V0::ContactsScope

  before_filter :set_scope
  before_filter :refine_scope # defined in ContactsSearch

  ##
  # Makes calculations on contacts
  #
  ##
  # Calculat average age for specified scope of contacts
  #
  # @url /v0/contacts/calculate
  # @url /v0/accounts/:account_name/contacts/calculate
  # @action GET/POST
  #
  # @optional [Date] ref_date . Date for which average age should be calculated. Default: Today
  #
  # @optional [String] account_name will scope contacts to this account
  # @optional [Array] nids return contacts without id in this array
  # @optional [Array] ids return contacts with id in this array
  # @optional [String] full_text will make a full_text search with this string.
  # @optional [Hash] where Mongoid where selector with additional keys -> :email, :telephone, :address, :local_status, :date_attribute
  # @optional [Array<Hash>] attributes_value_at Array of hashes with keys: :attribute, :value, :ref_date. This will be ANDed, not ORed.
  #
  # @example_request
  #   -- "Age for All contacts with birthdate on 21st May" --
  #   GET /v0/contacts/calculate/average_age, { where: { date_attribute: {day: 21, month: 5, category: 'Birthday' } }  }
  #
  # @example_response { result: '33,33' }
  #
  # @response_field [Float] result
  def average_age
    ref_date = params[:ref_date].to_date if params[:ref_date]
      
    ca = Calculate::Age.new contacts: @scope, ref_date: ref_date
    result = ca.average
    render json: { result: result }
  end

  private

  def set_scope
    @scope = @account.present?? @account.contacts : Contact.all
  end
end
