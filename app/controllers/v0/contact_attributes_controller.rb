class V0::ContactAttributesController < V0::ApplicationController

  before_filter :get_contact
  before_filter :set_scope

  def show
    @contact_attribute = @scope.find(params[:id])
    respond_to do |type|
      type.json {render :json => @contact_attribute}
    end
  end

  #  Updates specified values of a contact attribute
  #
  #  == Request:
  #   PUT /v0/contact_attributes/:id/
  #   PUT /v0/accounts/:account_name/contact_attributes/:id
  #
  #  == Valid params:
  #   :account_name [string]: (account name) scopes account
  #   :contact_id [string]: (account name) change de account the contact belongs to
  #   :id
  #   :contact_attribute
  #     :category [string]: change the name of the category
  #     :value [string]: change the value of the contact attribute
  #
  #  == Response:
  #   :response [string] = "OK" if success or error message
  #   :status [integer] = type of error
  def update
    authorize! :update, ContactAttribute
    @contact_attribute = @scope.find(params[:id])

    if @contact_attribute.update_attributes(params[:contact_attribute])
      render :json => "OK"# , :status => :updated
    else
      render :json => { :message => "Sorry, contact attribute not updated",
       :error_codes => [],
       :errors => @contact_attribute.errors }.to_json, :status => 400
    end
  end

  #  Returns a new contact attribute
  #
  #  == Request:
  #   POST /v0/contact_attribute_attributes
  #   POST /v0/accounts/:account_name/contact_attributes
  #
  #  == Valid params:
  #   :account_name [string]: (account name) account which the contact will belong to
  #
  #  == Response:
  #   :contact_attribute_id: [integer]: id of the contact attribute created
  def create
    authorize! :create, ContactAttribute

    @contact_attribute = @scope.new(params[:contact_attribute])
    @contact_attribute._type = params[:contact_attribute][:_type]
    @contact_attribute.account = @account

    if @contact_attribute.save
      render :json => { :id => @contact_attribute.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, contact attribute not created",
       :error_codes => [],
       :errors => @contact_attribute.errors }.to_json, :status => 400
    end
  end

  #  Destroys the contact attribute
  #
  #  == Request
  #    DELETE /v0/contact?attributes/:id
  #    DELETE /v0/accounts/:account_name/contacts/:contact_id/contact_attributes/:id
  #
  #  == Valid params:
  #  @param [String] account_name - scope to this accounts contacts
  #  @param [String] contact_id - contact id
  #
  #  == Response:
  #   :response [string]: "OK"
  def destroy
    @contact_attribute = @scope.find(params[:id])
    @contact_attribute.destroy if can?(:destroy, @contact_attribute)
    render :json => "OK"
  end

  private

  def get_contact
    @contact = @account.present?? @account.contacts.find(params[:contact_id]) : Contact.find(params[:contact_id])
  end

  #  Sets the scope
  def set_scope
    @scope = if @account && params[:contact_id]
      @contact.contact_attributes
    else
      @contact.contact_attributes
    end
  end

end
