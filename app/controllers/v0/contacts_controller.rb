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
  #   :list_name [String]: scope to this list. Will be ignored if no :account_name is given.
  #   :page [integer]: will return this page (default: 1)
  #   :per_page [integer]: will paginate contacts with this amount per page (default: 10)
  #   :full_text [String]: will make a full_text search with this string.
  #
  #  == Response:
  #   :collection [array]: array of contacts {:id, :name, :description, :items}
  #   :total [integer]: total contacts
  def index

    if params[:full_text]
      # full_text search
      @scope = @scope.csearch(params[:full_text])
    end
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
    render :json => @contact.as_json(:account => @account)
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
    # Fix for Typhoeus call bug
    if params[:contact] && params[:contact][:contact_attributes_attributes] && params[:contact][:contact_attributes_attributes].first.is_a?(String)
      params[:contact][:contact_attributes_attributes] = params[:contact][:contact_attributes_attributes].map {|att| ActiveSupport::JSON.decode(att.gsub(/=>/, ":").gsub(/nil/, "null"))}
    end

    @contact = @scope.create(params[:contact])

    # This is needed because contact_attributes are first created as ContactAttribute instead of _type!!
    @contact = @contact.reload unless @contact.new_record?

    if @contact.valid?
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

    # Fix for Typhoeus call bug
    if params[:contact] && params[:contact][:contact_attributes_attributes] && params[:contact][:contact_attributes_attributes].first.is_a?(String)
      params[:contact][:contact_attributes_attributes] = params[:contact][:contact_attributes_attributes].map {|att| ActiveSupport::JSON.decode(att.gsub(/=>/, ":").gsub(/nil/, "null"))}
    end

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
  #  == Request
  #    DELETE /v0/contacts/:id
  #    DELETE /v0/accounts/:account_name/contacts/:id
  #
  #  == Valid params:
  #  @param [String] account_name - scope to this accounts contacts
  #  @param [String] id - contact id
  #
  #  == Response:
  #   :response [string]: "OK"
  def destroy
    @contact = @scope.find(params[:id])
    @contact.destroy if @account && @contact.owner == @account
    render :json => "OK"
  end

  private

  #  Sets the scope
  def set_scope
    case action_name.to_sym
      when :index, :update, :create

        list = nil
        if @account && params[:list_name]
          list = List.where(account_id: @account._id, name: params[:list_name]).try(:first)
          unless list
            render :text => "List Not Found", :status => 404
          end
        end

        if @account && list
          @scope = list.contacts
        elsif @account
          @scope = @account.lists.first.contacts
        else
          @scope = Contact
        end

      when :destroy
        @scope = Contact
      else
        @scope = Contact
    end
  end
end