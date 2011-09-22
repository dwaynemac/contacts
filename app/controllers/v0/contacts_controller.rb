class V0::ContactsController < V0::ApplicationController

  before_filter :set_scope

  #  Returns list of contacts
  #
  #  == Request:
  #   GET /v0/contacts
  #   GET /v0/accounts/:account_name/contacts
  #
  #  == Valid params:
  #   :account_name [string]: (account name) will scope contacts to this account (required)
  #   :page [integer]: will return this page (default: 1)
  #   :per_page [integer]: will paginate contacts with this amount per page (default: 10)
  #
  #  == Response:
  #   :collection [array]: array of contacts {:id, :name, :description, :items}
  #   :total [integer]: total contacts
  def index
    @contacts = @scope.page(params[:page] || 1).per(params[:per_page] || 10)
    response.headers['Content-type'] = 'application/json; charset=utf-8'
    render :json => { :collection => @contacts, :total => @contacts.count }.to_json
  end

  #  Returns a contact
  #
  #  == Request:
  #   GET /v0/contacts/:id
  #   GET /v0/accounts/:account_name/contacts/:id
  #
  #  == Response:
  #   :contact [Checklist]: single contact {:id, :name, :description, :items}
  def show
    @contact = @scope.find(params[:id])
    render :json => @contact.to_json
  end

  #  Returns a new contact
  #
  #  == Request:
  #   POST /v0/contacts
  #   POST /v0/accounts/:account_name/contacts
  #
  #  == Valid params:
  #   :account_name [string]: (account name) account which the contact will belong to
  #   :name [string]: name of the contact
  #   :description [string]: short description of the contact
  #
  #  == Response:
  #   :contact_id: [integer]: id of the contact created
  def create
    @contact = @scope.new(params[:contact])
    if @contact.save
      render :json => { :id => @contact.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, contact not created",
       :error_codes => [],
       :errors => @contact.errors }.to_json, :status => 400
    end
  end

  #  Updates specified values of a contact
  #
  #  == Request:
  #   PUT /v0/contacts/:id
  #   PUT /v0/accounts/:account_name/contacts/:id
  #
  #  == Valid params:
  #   :account_name [string]: (account name) scopes account
  #   :contact [hash]:
  #     :account_id [string]: (account name) change de account the contact belongs to
  #     :name [string]: change the name of the contact
  #     :description [string]: change the description of the contact
  #
  #  == Response:
  #   :response [string] = "OK" if success or error message
  #   :status [integer] = type of error
  def update
    @contact = @scope.find(params[:id])
    if @contact.update_attributes(params[:contact])
      render :json => "OK"# , :status => :updated
    else
      render :json => { :message => "Sorry, contact not updated",
       :error_codes => [],
       :errors => @contact.errors }.to_json, :status => 400
    end
  end

  #  Destroys the contact
  #
  #  == Response:
  #   :response [string]: "OK"
  def destroy
    @contact = @scope.find(params[:id])
    @contact.destroy
    render :json => "OK"
  end

  private

  #  Sets the scope
  def set_scope
    @scope = Contact
    @scope = @account.owned_contacts if params[:account_name] # @account is created in V0::ApplicationController#get_account
  end
end
