# @restful_api v0
class V0::ImportsController < V0::ApplicationController

  before_filter :get_account

  def create
    contacts_CSV = params[:import][:file]
    headers = params[:import][:headers]

    import = Import.new(account: @account, headers: headers)
    import.attachment = Attachment.new(name: "CSV", file: contacts_CSV, account: @account)

    if import.save
      import.process_CSV
      render :json => {:message => "OK", :id => import.id}.to_json, :status => 201
    else
      render :json => {:message => "Sorry, import could not be created", :errors => import.errors}.to_json,
             :status => 400
    end
  end

  def show
    import = Import.find(params[:id])

    if import.nil?
      render :json => {:message => "Import not found"}.to_json, :status => 404
    else
      render :json => {:status => import.status,
                       :failed_rows => import.failed_rows.count,
                       :imported_rows => import.imported_ids.count}.to_json,
             :status => 201
    end
  end

  def failed_rows
    import = Import.find(params[:id])

    if import.nil? || import.status != :finished
      return
    #  render :json => {:message => "Import not found"}.to_json, :status => 404
    #elsif import.status != 'finished'
    #  render :json => {:message => "Import not finished"}.to_json, :status => 401
    end

    headers = import.headers
    # Add the header to the row number that failed at the beginning
    headers.unshift('row number')
    # Add the error column header
    headers << 'Errors'
    import.update_attribute(:headers, headers)

    respond_to do |format|
      format.csv { send_data import.to_csv, type: 'text/csv', disposition: "attachment; filename=import_errors.csv" }
    end
  end

  private

  #  Sets the scope
  def get_account
    @account = Account.where(name: params[:import][:account_name]).first
  end
end
