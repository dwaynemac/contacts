# @restful_api v0
class V0::ContactAttributesController < V0::ApplicationController

  before_filter :get_contact
  before_filter :set_scope

  ##
  # Returns an attribute of a contact
  # @url /v0/contact_attributes/:id
  # @action GET
  #
  # @required [String] id id of contact_attribute
  # @required [String] contact_id id of contact
  # @optional [String] account_name
  #
  # @response_code 200
  # @example_response { _type: 'Email', value: 'anemail@server.com', public: false}
  #
  # @author Luis Perichon
  def show
    @contact_attribute = @scope.find(params[:id])
    respond_to do |type|
      type.json {render :json => @contact_attribute}
    end
  end

  ##
  #  Updates specified values of a contact attribute
  #
  # @url /v0/contact_attributes/:id/ 
  # @action PUT
  # @url /v0/accounts/:account_name/contact_attributes/:id 
  # @action PUT
  #
  # @optional [String] account_name: (account name) scopes account
  # @required [String] contact_id: (account name) change de account the contact belongs to
  # @required [String] id
  #
  # @required [Hash] contact_attribute
  # @key_for contact_attribute [String] category
  # @key_for contact_attribute [String] value change the value of the contact attribute
  #
  # @example_response == Code: 200
  #   "OK"
  # @response_code 200
  #
  # @example_response == Code: 400
  #   { message: 'Sorry, contact attribute not updated', errors: [ ... ]}
  # @response_code 400
  #
  # @author Luis Perichon
  # @author Dwayne Macgowan
  def update
    authorize! :update, ContactAttribute
    @contact_attribute = @scope.find(params[:id])

    if @contact_attribute.update_attributes(params[:contact_attribute])
      @contact.index_keywords!
      render :json => "OK"# , :status => :updated
    else
      render :json => { :message => "Sorry, contact attribute not updated",
       :error_codes => [],
       :errors => @contact_attribute.errors }.to_json, :status => 400
    end
  end

  ##
  #  Returns a new contact attribute
  #
  # @url /v0/contact_attribute_attributes 
  # @url /v0/accounts/:account_name/contact_attributes
  # @action POST
  #
  # @required [String] contact_id contact id
  # @optional [String] account_name: account which the contact will belong to
  #
  # @response_code 201
  # @response_field contact_attribute_id [Integer] id of the contact attribute created
  #
  # @response_code 400
  # @response_field message [String] (for code: 400)
  # @response_field errors [Array] (for code: 400)
  def create
    authorize! :create, ContactAttribute

    @contact_attribute = @scope.new(params[:contact_attribute])
    @contact_attribute._type = params[:contact_attribute][:_type]
    @contact_attribute.account = @account

    if @contact_attribute.save
      @contact.index_keywords!
      render :json => { :id => @contact_attribute.id, :primary => @contact_attribute.primary }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, contact attribute not created",
       :error_codes => [],
       :errors => @contact_attribute.errors }.to_json, :status => 400
    end
  end

  ##
  #  Destroys the contact attribute
  #
  #  == Request
  # @url /v0/contact?attributes/:id 
  # @action DELETE
  # @url /v0/accounts/:account_name/contacts/:contact_id/contact_attributes/:id 
  # @action DELETE
  #
  # @optional [String] account_name scope to this accounts contacts
  # @required [String] contact_id contact id
  # @required [String] id
  #
  # @example_response "OK"
  def destroy
    @contact_attribute = @scope.find(params[:id])
    if can?(:destroy, @contact_attribute)
      if @contact_attribute.destroy
        @contact.index_keywords!
      end
    end
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
