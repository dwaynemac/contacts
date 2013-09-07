# @restful_api v0
class V0::ImportsController < V0::ApplicationController

  before_filter :get_account

  def create
    contacts_CSV = params[:file]
    headers = params[:headers]

    import = Import.new(account: @account, contacts_CSV: contacts_CSV, headers: headers)
    import.process_CSV

    # TODO send response

  end

  private

  #  Sets the scope
  def get_account
    @account = Account.where(name: params[:account_name]).first
  end
end
