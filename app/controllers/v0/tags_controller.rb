# @restful_api v0
class V0::TagsController < V0::ApplicationController
  before_filter :get_account
  before_filter :set_scope

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
    @tag = @scope.find(params[:id])
    respond_to do |type|
      type.json {render :json => @tag}
    end
  end

  ##
  # Returns all the tags of a contact or of an account
  # @url /v0/tags
  # @url /v0/accounts/:account_name/tags
  # @action GET
  #
  # @argument account_name [String]
  # @optional [String] contact_id id of contact, sets the scope for the contacts tag
  #
  # @response_code 200
  # @example_response { name: 'tag_name' }
  #
  # @author Alex Falke
  def index
    @tags = @scope
    respond_to do |type|
      type.json {render :json => @tags}
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
    authorize! :update, Tag
    @tag = @scope.find(params[:id])
    @contact = @account.contacts.find(params[:contact_id])

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
    authorize! :create, Tag

    @tag = @scope.new(params[:tag])
    @tag._type = "Tag"
    @tag.account = @account

    @contact = @account.contacts.find(params[:contact_id])

    if @tag.save
      @contact.index_keywords! unless @contact.nil?

      render :json => { :id => @tag.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, tag was not created",
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
    @tag = @scope.find(params[:id])
    if can?(:destroy, @tag)
      if @tag.destroy
        @contact.index_keywords!
      end
    end
    render :json => "OK"
  end

  def get_account
    @account = Account.where(name: params[:account_name]).first
  end

  def set_scope
    if params[:contact_id]
      @scope = @account.contacts.find(params[:contact_id]).tags
    else
      @scope = @account.tags
    end
  end
end