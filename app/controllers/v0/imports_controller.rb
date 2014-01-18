# @restful_api v0
class V0::ImportsController < V0::ApplicationController

  before_filter :get_account, except: :destroy

  ##
  # Returns status of an import
  # Available statuses are:
  #   * :ready
  #   * :working
  #   * :finished
  # @url /v0/imports/:id
  # @action GET
  #
  # @required [String] id import id
  #
  # @example_request
  # -- show me the status of the import 1234
  #
  # GET /v0/imports/1234, {id: "1234"}
  # @example response {status: 'working', failed_rows: 2, imported_rows: 10}
  #
  # @response_field [String] status status of the current import [:ready, :working, :finished]
  # @response_field [Integer] failed_rows number of rows that have already failed
  # @response_field [Integer] imported_rows number of rows that have already been imported
  #
  # @author Alex Falke
  def show
    import = Import.find(params[:id])

    if import.nil?
      render :json => {:message => "Import not found"}.to_json, :status => 404
    else
      render :json => {import: {:status => import.status,
                             :failed_rows => import.failed_rows.count,
                             :imported_rows => import.imported_ids.count}}.to_json,
             :status => 200
    end
  end


  ##
  # Creates an import that runs in the background.
  # Returns id of the import created
  # @url /v0/imports
  # @action POST
  #
  # @required [File] import[file]  CSV file to import
  # @required [Array] import[headers] headers of the CSV file
  # @required [String] account_name
  #
  # @example_request
  # -- import the data in "example.csv", with headers @headers, for the account "testAccount"
  #
  # POST /v0/imports, {import: {file: example.csv, headers: @headers}, account_name: "testAccount"}
  # @example response {message: "OK", id: 1234}
  #
  # @response_field [Integer] id of import being processed
  # @response_field [String] OK message
  #
  # @author Alex Falke
  def create
    contacts_CSV = params[:import][:file]
    headers = params[:import][:headers]

    import = Import.new(account: @account, headers: headers)
    import.attachment = Attachment.new(name: "CSV", file: contacts_CSV, account: @account)

    if import.save
      import.process_CSV
      render :json => {:message => "OK", :id => import.id}.to_json, :status => 201
    else
      Rails.logger.info("Import not created: #{import.errors}")
      render :json => {:message => "Sorry, import could not be created", :errors => import.errors}.to_json,
      :status => 400
    end
  end


  ##
  # Returns a CSV file with the import errors
  # @url /v0/imports/:id/failed_rows.csv
  # @action GET
  #
  # @required [String] id import id
  #
  # @example_request
  # -- give me the CSV file with the contacts that have not been imported
  #
  # GET /v0/imports/1234/failed_errors.csv, {id: "1234"}
  # @example response { CSV }
  #
  # @response_field [CSV] csv file with the errors that ocurred during import
  #
  # @author Alex Falke
  def failed_rows
    import = Import.find(params[:id])

    if import.nil? || import.status != :finished
      render :json => {:message => "Import not found"}.to_json, :status => 404
    else
      headers = import.headers
      
      # Add the header to the row number that failed at the beginning
      headers.unshift('row number')
      # Add the error column header
      headers << 'Errors'
      import.headers = headers

      respond_to do |format|
        format.csv { send_data import.failed_rows_to_csv, type: 'text/csv', disposition: "attachment; filename=import_errors.csv" }
      end
    end
  end

  ##
  # Destroys given import and the contacts it imported
  # @url /v0/imports/:id
  # @action DELETE
  #
  # @required [String] id import id
  #
  # @example_request
  #
  # DELETE /v0/imports/1234, {id: "1234"}
  # @example response
  #
  # @author Dwayne Macgowan
  def destroy
    @import = Import.find params[:id]
    if @import.status.to_sym != :working
      @import.destroy
      render json: 'destroyed', status: 200
    else
      render json: "Import is currently working, wait for it to finish before deletion.",
             status: 409
    end
  end
end
