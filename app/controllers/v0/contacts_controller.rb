##
# @url  /v0/contacts
# @topic Contacts
class V0::ContactsController < V0::ApplicationController

  before_filter :set_list
  before_filter :set_scope
  before_filter :convert_local_attributes, only: [:create, :update]

  ##
  # Returns list of contacts in JSON
  #
  # @url [GET] /v0/contacts
  # @url [GET] /v0/accounts/:account_name/contacts
  #
  # @optional_argument nids [Array] return contacts without id in this array
  # @optional_argument ids [Array] return contacts with id in this array
  # @optional_argument account_name [String] will scope contacts to this account
  # @optional_argument list_name [String] scope to this list. Will be ignored if no :account_name is given.
  # @optional_argument page [Integer] will return this page (default: 1)
  # @optional_argument per_page [Integer] will paginate contacts with this amount per page (default: 10)
  # @optional_argument full_text [String] will make a full_text search with this string.
  # @optional_argument where [Hash] Mongoid where selector with additional keys -> :email, :telephone, :address, :local_status
  # @optional_argument attributes_value_at [Array<Hash>] Array of hashes with keys: :attribute, :value, :ref_date. This will be ANDed, not ORed.
  #
  # @example_response { collection: [ {_id: 1234,name: ...} ], total: 1}
  #
  # @response_field collection [Array <Contact>] corresponding to chosen :page
  # @response_field total [Integer] total amount of contacts in query. (includes all pages.)
  #
  def index

    params[:attribute_values_at].each do |ava|
      @scope = @scope.with_attribute_value_at(ava['attribute'],ava['value'],ava['ref_date'])
    end if params[:attribute_values_at]

    @scope = @scope.not_in(_id: params[:nids]) if params[:nids]
    @scope = @scope.any_in(_id: params[:ids]) if params[:ids]

    @scope = @scope.csearch(params[:full_text]) if params[:full_text].present?
    @scope = @scope.api_where(params[:where], @account.try(:id))   if params[:where].present?
    @scope = @scope.order_by(normalize_criteria(params[:sort].to_a)) if params[:sort].present?

    total = @scope.count
    @contacts = @scope.page(params[:page] || 1).per(params[:per_page] || 10)

    response.headers['Content-type'] = 'application/json; charset=utf-8'
    render :json => { :collection => @contacts, :total => total}.as_json(account: @account)
  end

  # @url [POST] /v0/contacts/search
  # @see index
  def search
    index
  end

  ##
  # Returns JSON for a contact
  # if account is provided following attributes will be inclueded:
  #   * owned by account
  #   * public attributes
  #   * masked attributes
  #
  # @url [GET] /v0/contacts/:id
  # @url [GET] /v0/accounts/:account_name/contacts/:id
  #
  # @argument id [String] contact_id
  # @optional_argument account_name [String] scope search to this account. Fields will be added to response when this is sent.
  #
  # @example_response
  #   if account_name is provided
  #     {id: '124365w45215', first_name: 'Dwayne', last_name: 'Macgowan'}
  #   else
  #     {id: '123', first_name: 'Dwa', last_name: 'Mac', linked: true}
  #
  # @response_field [TrueClass] linked
  #   is this contact linked to :account_name?
  # @response_field [String] first_name
  # @response_field [String] last_name
  def show
    @contact = @scope.find(params[:id])
    render :json => @contact.as_json(:account => @account, :include_masked => true)
  end

  ##
  # Creates a contact
  #
  # @url [POST] /v0/contacts
  # @url [POST] /v0/accounts/:account_name/contacts
  #
  # @argument account_name [String] account which the contact will belong to
  # @argument name [String] name of the contact
  #
  # @example_response == Successfull (status: created)
  #   { id: '245po46sjlka' }
  #
  # @example_response == Failed (status: 400)
  #   {
  #     message: 'Sorry, contact not created',
  #     errors: [ email: 'not valid' ]
  #   }
  #
  # @response_field id [Integer] id of the contact created. (only for status: 201)
  # @response_field message [String] error message. (only for status: 400)
  # @response_field errors [Hash] model message errors
  # @response_code success 201
  # @response_code failure 400
  #
  def create

    authorize! :create, Contact

    @contact =  @scope.new(params[:contact])

    # This is needed because contact_attributes are first created as ContactAttribute instead of _type!!
    @contact = @contact.reload unless @contact.new_record?

    #set again check duplicates virtual attribute (lost after reloading)
    @contact.check_duplicates = params[:contact][:check_duplicates]

    if @contact.save

      entry = ActivityStream::Activity.new(
          target_id: @contact.owner_name, target_type: 'Account',
          object_id: @contact._id, object_type: 'Contact',
          generator: 'contacts',
          verb: 'created',
          content: "#{params[:username]} created #{@contact.full_name} on #{@contact.owner_name}",
          public: true,
          username: params[:username] || 'system',
          account_name: params[:account_name] || 'system',
          created_at: @contact.created_at.to_s,
          updated_at: @contact.updated_at.to_s
      )
      entry.create(username:  params[:username], account_name: params[:account_name])

      render :json => { :id => @contact.id }.to_json, :status => :created
    else
      render :json => { :message => "Sorry, contact not created",
       :error_codes => [],
       :errors => @contact.deep_error_messages }.to_json, :status => 400
    end
  end

  ##
  # Updates specified values of a contact
  #
  # @url [PUT] /v0/contacts/:id
  # @url [PUT] /v0/accounts/:account_name/contacts/:id
  #
  # @argument id [String] contact id
  # @optional_argument account_name [String] scopes account
  # @argument contact [hash] contact attributes
  #
  # @example_response == Successfull
  #   "OK"
  #
  # @example_response == Failed (status: 400)
  #   {
  #     message: 'Sorry, contact not updated',
  #     errors: [ email: 'is invalid' ]
  #   }
  def update
    @contact = @scope.find(params[:id])

    if @contact.update_attributes(params[:contact])
      render :json => "OK"# , :status => :updated
    else
      render :json => { :message => "Sorry, contact not updated",
       :error_codes => [],
       :errors => @contact.deep_error_messages }.to_json, :status => 400
    end
  end

  ##
  # Links contact to account
  # @url [POST] v0/contacts/:id/link
  # @argument id [String]
  # @argument account_name [String]
  # @example_response == Successfull
  #   "OK"
  # @example_response == Failure (status: 400)
  #   {message: 'Sorry, couldnt link contact', errors: [...]}
  def link
    @contact = Contact.find(params[:id])
    if @account && @contact.link(@account)
      render :json => "OK"
    else
      render :json => {
        :message => "Sorry, couldnt link contact",
        :errors => @contact.deep_error_messages
      }.to_json, :status => 400
    end
  end

  # Will destory contact if no account specified or unlink it from specified account
  #
  # @url [DELETE] /v0/contacts/:id
  # @url [DELETE] /v0/accounts/:account_name/contacts/:id
  #
  # @argument [String] account_name - scope to this accounts contacts
  # @argument [String] id - contact id
  #
  # @example_response "OK"
  def destroy
    @contact = @scope.find(params[:id])
    if @account
      @contact.unlink(@account)
    else
      @contact.destroy if can?(:destroy, @contact)
    end
    render :json => "OK"
  end

  # Deletes multiple contacts
  #
  # @url [DELETE] /v0/contacts/destroy_multiple
  #
  # @argument ids [Array <String>] id of each contact to be destroyed/unlinked
  #
  # @optional_argument account_name [String]
  #
  # @example_response "OK"
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

  # Calculates a given statistic and returns value
  # @url [GET] /v0/contacts/calculate
  #
  # @argument [String] name. Statistic code name.
  #
  # @argument [String] account_name. Account to scope to
  # @argument [Integer] year. Year to scope to
  # @argument [Integer] month. Month to scope to
  #
  #
  # @example_response {value: 12}
  # @response_field value [Integer]
  # @response_code 200
  def calculate

    required_arguments = %W(account_name year month)

    required_arguments.each do |required_argument|
      unless params.keys.include?(required_argument)
        raise ArgumentError
      end
    end

    case params[:name]
      when 'xxx'
        # calculate xxx statistic
      else
        raise ArgumentError
    end

    render json: { value: value }, status: 200
  rescue ArgumentError
    render text: "error", status: 404
  end

  private

  # Converts
  #   local_status -> local_status_for_CurrentAccountName
  #   coefficient  -> coefficient_for_CurrentAccountName
  # If there is no current_account (@account) then key is removed from attributes hash.
  def convert_local_attributes
    %w(local_status coefficient local_teacher).each do |la|
      if @account
        if params[:contact][la]
          params[:contact]["#{la}_for_#{@account.name}"] = params[:contact].delete(la)
        end
      else
        params[:contact].delete(la)
      end
    end
  end


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
      when :index, :search, :update
        @account.present?? (@list.present?? @list.contacts : @account.contacts ) : Contact
      when :create
        @account.present?? (@list.present?? @list.contacts : @account.owned_contacts) : Contact
      when :destroy, :destroy_multiple
        @account.present?? @account.contacts : Contact
      else
        Contact
    end
  end

  # Sort by normalized fields
  def normalize_criteria(criteria)
    if criteria.is_a? Array then
      criteria.map! { |crit| normalize_criteria crit }
    elsif /^(first_name|last_name)$/.match(criteria) then
      criteria = 'normalized_' + criteria
    end
    criteria
  end
end
