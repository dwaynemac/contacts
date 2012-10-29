# @topic Attachments
# @url /v0/attachments
class V0::AttachmentsController < V0::ApplicationController

  before_filter :get_contact
  before_filter :set_scope

  ##
  # Returns an attachment of a contact
  # @url [GET] /v0/attachments/:id
  #
  # @argument id [String] id of attachment
  # @argument contact_id [String] id of contact
  # @optional_argument account_name [String]
  #
  # @response_code 200
  # @example_response { _type: 'Attachment', file: 'amazom.com/uploads/file.jpg', public: false}
  #
  # @author Alex Falke
  def show
    @attachment = @scope.find(params[:id])
    respond_to do |type|
      type.json {render :json => @attachment}
    end
  end

  ##
  #  Updates specified values of an attachment
  #
  # @url [PUT] /v0/attachment/:id/
  # @url [PUT] /v0/accounts/:account_name/attachment/:id
  #
  # @optional_argument account_name [String]: (account name) scopes account
  # @argument contact_id [String]: (account name) change de account the contact belongs to
  # @argument id [String]
  #
  # @argument contact_attributes [Hash]
  # @key_for contact_attributes [String] category
  # @key_for contact_attributes [String] file changes the file associated with this attachment
  # @key_for contact_attributes [String] value change the value of the contact attribute
  #
  # @example_response == Code: 200
  #   "OK"
  # @response_code 200
  #
  # @example_response == Code: 400
  #   { message: 'Sorry, contact attribute not updated', errors: [ ... ]}
  # @response_code 400
  #
  # @author Alex Falke
  def update
    authorize! :update, Attachment
    @attachment = @scope.find(params[:id])

    if @attachment.update_attributes(params[:contact_attributes])
      @contact.index_keywords!
      render :json => "OK"
    else
      render :json => { :message => "Sorry, attachment not updated",
       :error_codes => [],
       :errors => @contact_attribute.errors }.to_json, :status => 400
    end
  end

  ##
  #  Returns a new attachment
  #
  # @url [POST] /v0/attachments
  # @url [POST] /v0/accounts/:account_name/attachments
  #
  # @argument contact_id [String] contact id
  # @optional_argument account_name [String]: account which the contact will belong to
  # @optional_argument file [File]: file to be attached
  #
  # @response_code 201
  # @response_field attachment_id [Integer] id of the attachment created
  #
  # @response_code 400
  # @response_field message [String] (for code: 400)
  # @response_field errors [Array] (for code: 400)
  def create
    authorize! :create, Attachment

    @contact_attachment = @scope.new(params[:contact_attributes])
    @contact_attachment._type = "Attachment"
    @contact_attachment.account = @account

    if @contact_attachment.save
      @contact.index_keywords!

      render :json => { :id => @contact_attachment.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, attachment was not created",
       :error_codes => [],
       :errors => @contact_attachment.errors }.to_json, :status => 400
    end
  end

  ##
  #  Destroys the attachment
  #
  #  == Request
  # @url [DELETE] /v0/attachments/:id
  # @url [DELETE] /v0/accounts/:account_name/contacts/:contact_id/attachments/:id
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
