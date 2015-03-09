# @restful_api v0
class V0::AttachmentsController < V0::ApplicationController

  authorize_resource

  before_filter :get_contact
  before_filter :set_scope

  ##
  # Returns an attachment of a contact
  # @url /v0/attachments/:id
  # @action GET
  #
  # @required [String] id  id of attachment
  # @required [String] contact_id  id of contact
  # @optional [String] account_name
  #
  # @response [Attachment] selected attachment
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
  # @url /v0/attachment/:id/
  # @url /v0/accounts/:account_name/attachment/:id
  # @action PUT
  #
  # @required [String] contact_id change de account the contact belongs to
  # @required [String] id
  #
  # @optional [String] account_name scopes account
  #
  # @required [ContactAttribute] contact_attributes
  # @optional [String] contact_attributes[category]
  # @optional [String] contact_attributes[file] changes the file associated with this attachment
  # @optional [String] contact_attributes[value] change the value of the contact attribute
  #
  # @author Alex Falke
  def update
    authorize! :update, Attachment
    @attachment = @scope.find(params[:id])

    if @attachment.update_attributes(params[:attachment])
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
  # @url /v0/attachments
  # @url /v0/accounts/:account_name/attachments
  #
  # @action POST
  #
  # @optional [String] contact id
  # @optional [String] account_name account which the contact will belong to
  # @optional [String] kshema_id kshema_id of the contact
  # @optional [File] file file to be attached
  #
  def create
    authorize! :create, Attachment

    @attachment = @scope.new(params[:attachment])
    @attachment._type = "Attachment"
    @attachment.account = @account

    if @attachment.save
      @contact.index_keywords!

      render :json => { :id => @attachment.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, attachment was not created",
       :error_codes => [],
       :errors => @attachment.errors }.to_json, :status => 400
    end
  end

  ##
  #  Destroys the attachment
  #
  #  == Request
  # @url /v0/attachments/:id
  # @url /v0/accounts/:account_name/contacts/:contact_id/attachments/:id
  # @action DELETE
  #
  # @optional [String] account_name  scope to this accounts contacts
  # @required [String] contact_id  contact id
  # @required [String] id
  #
  # @example_response "OK"
  def destroy
    @attachment = @scope.find(params[:id])
    if can?(:destroy, @attachment)
      if @attachment.destroy
        @contact.index_keywords!
      end
    end
    render :json => "OK"
  end

  private

  def get_contact
    if params.has_key?(:kshema_id)
      if @account.present?
        @contact = @account.contacts.where(kshema_id: params[:kshema_id]).first
      else
        @contact = Contact.where(kshema_id: params[:kshema_id]).first
      end
    else
      @contact = @account.present?? @account.contacts.find(params[:contact_id]) : Contact.find(params[:contact_id])
    end
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
