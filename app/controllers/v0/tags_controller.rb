# @topic Tags
# @url /v0/tags
class V0::TagsController < V0::ApplicationController
  before_filter :get_account
  before_filter :set_scope

  ##
  # Returns a specific tag of a contact or of an account
  # @url [GET] /v0/tags/:id
  # @url [GET] /v0/accounts/:account_name/tags/:id
  #
  # @argument id [String] id of tag
  # @argument contact_id [String] id of contact
  # @optional_argument account_name [String]
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
  # @url [GET] /v0/tags
  # @url [GET] /v0/accounts/:account_name/tags
  #
  # @argument account_name [String]
  # @optional_argument contact_id [String] id of contact, sets the scope for the contacts tag
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
  # @url [PUT] /v0/tags/:id/
  # @url [PUT] /v0/accounts/:account_name/tag/:id
  #
  # @optional_argument account_name [String]: (account name) scopes account
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
  # @url [POST] /v0/tags
  # @url [POST] /v0/accounts/:account_name/tags
  #
  # @argument contact_id [String] contact id
  # @optional_argument account_name [String]: account which the contact will belong to
  # @optional_argument name [String]: name of the tag
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
  #  == Request
  # @url [DELETE] /v0/tags/:id
  # @url [DELETE] /v0/accounts/:account_name/tags/:id
  #
  # @optional_argument account_name [String] scope to this accounts contacts
  # @argument contact_id [String] contact id
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