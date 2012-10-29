# @topic Attributes
# @url /v0/contact_attributes
class V0::AttachmentsController < V0::ApplicationController

  before_filter :get_contact
  before_filter :set_scope

  ##
  # Returns an attribute of a contact
  # @url [GET] /v0/contact_attributes/:id
  #
  # @argument id [String] id of contact_attribute
  # @argument contact_id [String] id of contact
  # @optional_argument account_name [String]
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
  # @url [PUT] /v0/contact_attributes/:id/
  # @url [PUT] /v0/accounts/:account_name/contact_attributes/:id
  #
  # @optional_argument account_name [String]: (account name) scopes account
  # @argument contact_id [String]: (account name) change de account the contact belongs to
  # @argument id [String]
  #
  # @argument contact_attribute [Hash]
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
    authorize! :update, Attachment
    @attachment = @scope.find(params[:id])
    #@attachment.file = params[:contact_attributes][:file]
    if @attachment.update_attributes(params[:contact_attributes])
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
  # @url [POST] /v0/contact_attribute_attributes
  # @url [POST] /v0/accounts/:account_name/contact_attributes
  #
  # @argument contact_id [String] contact id
  # @optional_argument account_name [String]: account which the contact will belong to
  #
  # @response_code 201
  # @response_field contact_attribute_id [Integer] id of the contact attribute created
  #
  # @response_code 400
  # @response_field message [String] (for code: 400)
  # @response_field errors [Array] (for code: 400)
  def create
    authorize! :create, Attachment

    @contact_attachment = @scope.new(params[:contact_attributes])
    @contact_attachment._type = "Attachment"
    @contact_attachment.account = @account
    #attach.attachment = params[:contact_attribute][:attachment]

    # puts "ANTES DE GRABAR ATTACHMENT: #{@contact_attachment.inspect}"
    # puts "EL CONTACT es: #{@contact.inspect}"
    if @contact_attachment.save
      # puts "GENERO UNO NUEVO"
      # puts "ESTOY GRABANDO ATTACHMENT CON #{@contact_attachment.inspect}"
      # puts "ATTACHMENT URL QUEDO: #{@contact_attachment.file.url}"
      @contact.index_keywords!

      render :json => { :id => @contact_attachment.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, attachment was not created",
       :error_codes => [],
       :errors => @contact_attachment.errors }.to_json, :status => 400
    end
  end

  ##
  #  Destroys the contact attribute
  #
  #  == Request
  # @url [DELETE] /v0/contact?attributes/:id
  # @url [DELETE] /v0/accounts/:account_name/contacts/:contact_id/contact_attributes/:id
  #
  # @optional_argument account_name [String] scope to this accounts contacts
  # @argument contact_id [String] contact id
  # @argument id [String]
  #
  # @example_response "OK"
  def destroy
    @contact_attachment = @scope.find(params[:id])
    if can?(:destroy, @contact_attachment)
      if @contact_attachment.destroy
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
      @contact.attachments
    else
      @contact.attachments
    end
  end

end
