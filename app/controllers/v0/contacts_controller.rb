class V0::ContactsController < V0::ApplicationController

  before_filter :set_list
  before_filter :set_scope
  before_filter :typhoeus_bugfix, :only => [:create, :update]

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
  #   :where [Hash]:
  #
  #  == Response:
  #   :collection [array]: array of contacts {:id, :name, :description, :items}
  #   :total [integer]: total contacts
  def index

    do_full_text_search

    apply_where_conditions

    total = @scope.count
    @contacts = @scope.page(params[:page] || 1).per(params[:per_page] || 10)

    response.headers['Content-type'] = 'application/json; charset=utf-8'
    render :json => { :collection => @contacts, :total => total}.to_json
  end

  # Returns a contact
  #
  # @todo add support for tags :topic, :url, :argument, :example_response, :response_field
  # @topic Contacts
  # @url [GET] /v0/contacts/:id
  # @url [GET] /v0/accounts/:account_name/contacts/:id
  #
  # @argument [String] id contact_id (required)
  # @argument [String] account_name scope search to this account. Fields will be added to response when this is sent.
  #
  # @example_response without account_name
  # {id: '124365w45215', first_name: 'Dwayne', last_name: 'Macgowan'}
  #
  # @example_response with account_name
  # {id: '123', first_name: 'Dwa', last_name: 'Mac', linked: true}
  #
  # @response_filed [TrueClass] linked (only when scoped to account)
  #
  # @response_field [String] first_name Contacts first name
  def show
    @contact = @scope.find(params[:id])
    render :json => @contact.as_json(:account => @account, :include_masked => true)
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

    authorize! :create, Contact

    # use @scope.create because @scope.new; @contact.save won't correctly run callbacks
    @contact =  @scope.create(params[:contact])


    # This is needed because contact_attributes are first created as ContactAttribute instead of _type!!
    @contact = @contact.reload unless @contact.new_record?

    if @contact.valid?
      render :json => { :id => @contact.id }.to_json, :status => :created
    else
      if @contact.persisted?
        # it was created but after creation it was found invalid
        # TODO FIXME this should not be necessary
        @contact.destroy
      end

      render :json => { :message => "Sorry, contact not created",
       :error_codes => [],
       :errors => @contact.deep_error_messages }.to_json, :status => 400
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

    if params[:contact][:local_status] && @account
      params[:contact][:local_status] = {:account_id => @account.id, :status => params[:contact].delete(:local_status)}
    end

    if @contact.update_attributes(params[:contact])
      render :json => "OK"# , :status => :updated
    else
      render :json => { :message => "Sorry, contact not updated",
       :error_codes => [],
       :errors => @contact.deep_error_messages }.to_json, :status => 400
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
    if @account
      @contact.unlink(@account)
    else
      @contact.destroy if can?(:destroy, @contact)
    end
    render :json => "OK"
  end

  def destroy_multiple
    @contacts = @scope.any_in('_id' => params[:ids])
    @contacts.each do |c|
      if @account
        c.unlink(@account)
      else
        c.destroy if can?(:destroy, c)
      end
    end
    render json: 'OK'
  end

  private

  def set_list
    if @account && params[:list_name]
      # request specifies account and list
      @list = List.where(account_id: @account._id, name: params[:list_name]).try(:first)
      unless @list
        render :text => "List Not Found", :status => 404
      end
    end
  end

  #  Sets the scope
  def set_scope
    @scope = case action_name.to_sym
      when :index, :update
        @account.present?? (@list.present?? @list.contacts : @account.contacts ) : Contact
      when :create
        @account.present?? (@list.present?? @list.contacts : @account.owned_contacts) : Contact
      when :destroy, :destroy_multiple
        @account.present?? @account.contacts : Contact
      else
        Contact
    end
  end

  # Fix for Typhoeus call bug
  def typhoeus_bugfix
    c = params[:contact]

    return if c.nil?
    if c[:contact_attributes_attributes] && c[:contact_attributes_attributes].first.is_a?(String)
      c[:contact_attributes_attributes] = c[:contact_attributes_attributes].map {|att| ActiveSupport::JSON.decode(att.gsub(/=>/, ":").gsub(/nil/, "null"))}
    end

    params[:contact] = c
  end

  # TODO refactor into model
  def do_full_text_search
    return if params[:full_text].blank?

    @scope = @scope.csearch(params[:full_text])
  end

  # TODO refactor into model
  def apply_where_conditions
    return if params[:where].blank?

    params[:where].each do |k,v|
      if v.blank?
        # skip blanks
      elsif v.is_a?(Hash)
        v.each do |sk, sv|
          @scope = @scope.where("#{k}.#{sk}" => Regexp.new(sv))
          # TODO recursive call for sub-sub-hashes
        end
      elsif k.to_s.in?(%W(telephone email address custom_attribute))
        @scope = @scope.where(contact_attributes: { '$elemMatch' => { "_type" => k.to_s.camelize, "value" => Regexp.new(v)}})
      elsif k.to_s == 'local_status' && @account.present?
        # Service Consumer asks for local_status but we must map this to HIS local_status
        @scope = @scope.where(local_statuses: { '$elemMatch' => {account_id: @account.id, status: v}})
      else
        @scope = @scope.where(k => Regexp.new(v))
      end
    end
  end

end
