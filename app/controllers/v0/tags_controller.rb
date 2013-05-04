# @restful_api v0
class V0::TagsController < V0::ApplicationController
  before_filter :get_account

  load_and_authorize_resource
  skip_load_resource only: :index

  ##
  # Returns all the tags of a contact or of an account
  # @url /v0/tags
  # @url /v0/accounts/:account_name/tags
  # @action GET
  #
  # @required account_name [String]
  # @optional [String] contact_id id of contact, sets the scope for the contacts tag
  #
  # @author Alex Falke
  def index
    if params[:contact_id]
       @tags = Contact.find(params[:contact_id]).tags
    else
      @tags = @account.tags
    end
    respond_to do |type|
      type.json {render :json => { :collection => @tags, :total => @tags.count}}
    end
  end


  ##
  # Returns a specific tag of a contact or of an account
  # @url /v0/tags/:id
  # @url /v0/accounts/:account_name/tags/:id
  # @url /v0/accounts/:account_name/contacts/:contact_id/tags/:id
  # @action GET
  #
  # @required [String] id id of tag
  # @required [String] contact_id id of contact
  # @optional [String] account_name
  #
  # @response_code 200
  # @example_response { name: 'tag_name' }
  #
  # @author Alex Falke
  def show
    respond_to do |type|
      type.json {render :json => @tag}
    end
  end

  ##
  #  Returns a new tag
  #
  # @url /v0/tags
  # @url /v0/accounts/:account_name/tags
  # @action POST
  #
  # @required [String] contact_id contact id
  # @optional [String] account_name: account which the contact will belong to
  # @optional [String] name: name of the tag
  #
  # @response_code 201
  # @response_field tag_id [Integer] id of the tag created
  #
  # @response_code 400
  # @response_field message [String] (for code: 400)
  # @response_field errors [Array] (for code: 400)
  def create
    @tag.account_id = @account.id
    @tag.contact_ids = [params[:contact_ids]]

    if @tag.save
      if params[:contact_ids]
        contact = Contact.find(params[:contact_ids])
        contact.index_keywords! unless contact.nil?
      end

      render :json => { :id => @tag.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, tag was not created",
                        :error_codes => [],
                        :errors => @tag.errors }.to_json, :status => 400
    end
  end

  ##
  #  Updates specified values of a tag
  #
  # @url /v0/tags/:id/
  # @url /v0/accounts/:account_name/tag/:id
  # @action PUT
  #
  # @optional [String] account_name: (account name) scopes account
  # @argument id [String]
  #
  # @argument contact_attributes [Hash]
  # @key_for contact_attributes [String] category
  # @key_for contact_attributes [String] value change the value of the contact attribute
  #
  # @example_response == Code: 200
  #   "OK"
  # @response_code 200
  #
  # @example_response == Code: 400
  #   { message: 'Sorry, tag not updated', errors: [ ... ]}
  # @response_code 400
  #
  # @author Alex Falke
  def update
    @contact = Contact.find(params[:contact_id])

    if @tag.update_attributes(params[:tag])
      @contact.index_keywords! unless @contact.nil?
      render :json => "OK"
    else
      render :json => { :message => "Sorry, tag not updated",
                        :error_codes => [],
                        :errors => @tag.errors }.to_json, :status => 400
    end
  end

  ##
  #  Destroys the tag
  #
  # @url /v0/tags/:id
  # @url /v0/accounts/:account_name/tags/:id
  # @action DELETE
  #
  # @optional [String] account_name scope to this accounts contacts
  # @required [String] contact_id contact id
  # @argument id [String]
  #
  # @example_response "OK"
  def destroy
    if @tag.destroy
      if params[:contact_id]
        contact = Contact.find(params[:contact_id])
        contact.index_keywords! unless contact.nil?
      end
    end
    render :json => "OK"
  end

  private

  def get_account
    @account = Account.where(name: params[:account_name]).first
  end
end