##
# @restful_api v0
class V0::ContactsController < V0::ApplicationController

  before_filter :set_list
  before_filter :set_scope
  before_filter :convert_local_attributes, only: [:create, :update]

  ##
  # Returns list of contacts in JSON
  #
  # @url /v0/contacts
  # @url /v0/accounts/:account_name/contacts
  # @action GET
  #
  # @optional [Array] nids return contacts without id in this array
  # @optional [Array] ids return contacts with id in this array
  # @optional [String] account_name will scope contacts to this account
  # @optional [String] list_name scope to this list. Will be ignored if no :account_name is given.
  # @optional [Integer] page will return this page (default: 1)
  # @optional [Integer] per_page will paginate contacts with this amount per page (default: 10)
  # @optional [String] full_text will make a full_text search with this string.
  # @optional [Hash] where Mongoid where selector with additional keys -> :email, :telephone, :address, :local_status, :date_attribute
  # @optional [Array<Hash>] attributes_value_at Array of hashes with keys: :attribute, :value, :ref_date. This will be ANDed, not ORed.
  #
  # @example_request
  #   -- "All contacts with birthdate on 21st May" --
  #
  #   POST /v0/contacts/search, { where: { date_attribute: {day: 21, month: 5, category: 'Birthday' } }  }
  # @example_response { collection: [ {_id: 1234,name: ...} ], total: 1}
  #
  # @response_field [Array <Contact>] collection corresponding to chosen :page
  # @response_field [Integer] total total amount of contacts in query. (includes all pages.)
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
    render :json => { :collection => @contacts, :total => total}.as_json(account: @account, except_linked:true, except_last_local_status: true, only_name: params[:only_name].present?)
  end

  # @url /v0/contacts/search
  # @action POST
  # @see index
  def search
    index
  end

  def search_for_select
    @scope = @scope.csearch(params[:full_text]) if params[:full_text].present?
    @scope = @scope.api_where(params[:where], @account.try(:id))   if params[:where].present?
    @scope = @scope.order_by(normalize_criteria(params[:sort].to_a)) if params[:sort].present?

    total = @scope.count
    @contacts = @scope.page(params[:page] || 1).per(params[:per_page] || 10)

    respond_to do |format|
      format.js { render :json => { :collection => @contacts, :total => total}.as_json(account: @account, except_linked:true, except_last_local_status: true, only_name: params[:only_name].present?), :callback => params[:callback] }
    end    
  end  

  ##
  # Returns JSON for a contact
  # if account is provided following attributes will be inclueded:
  #   * owned by account
  #   * public attributes
  #   * masked attributes
  #
  # @url /v0/contacts/:id
  # @action GET
  # @url /v0/accounts/:account_name/contacts/:id
  # @action GET
  #
  # @required [String] id contact_id
  # @optional [String] account_name scope search to this account. Fields will be added to response when this is sent.
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
  # @url /v0/contacts
  # @action POST
  # @url /v0/accounts/:account_name/contacts
  # @action POST
  #
  # @required [String] account_name account which the contact will belong to
  # @required [String] name name of the contact
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
  # @response_field [Integer] id id of the contact created. (only for status: 201)
  # @response_field [String] message error message. (only for status: 400)
  # @response_field [Hash] errors model message errors
  # @response_code success 201
  # @response_code failure 400
  #
  def create

    authorize! :create, Contact

    @contact =  @scope.new(params[:contact])

    @contact.request_account_name = params[:account_name]
    @contact.request_username = params[:username]

    # This is needed because contact_attributes are first created as ContactAttribute instead of _type!!
    @contact = @contact.reload unless @contact.new_record?

    #set again check duplicates virtual attribute (lost after reloading)
    @contact.check_duplicates = params[:contact][:check_duplicates]

    if @contact.save
      @contact.index_keywords!
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
  # @url /v0/contacts/:id
  # @action PUT
  # @url /v0/accounts/:account_name/contacts/:id
  # @action PUT
  #
  # @required [String] id contact id
  # @optional [String] account_name scopes account
  # @required [hash] contact contact attributes
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

    @contact.check_duplicates = false

    @contact.request_username = params[:username]
    @contact.request_account_name = params[:account_name]

    if @contact.update_attributes(params[:contact])
      @contact.index_keywords!
      render :json => "OK"# , :status => :updated
    else
      render :json => { :message => "Sorry, contact not updated",
       :error_codes => [],
       :errors => @contact.deep_error_messages }.to_json, :status => 400
    end
  end

  ##
  # Links contact to account
  # @url v0/contacts/:id/link
  # @action POST
  # @required [String] id
  # @required [String] account_name
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
  # @url /v0/contacts/:id
  # @url /v0/accounts/:account_name/contacts/:id
  # @action DELETE
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
  # @url /v0/contacts/destroy_multiple
  # @action DELETE
  #
  # @required [Array <String>] ids id of each contact to be destroyed/unlinked
  #
  # @optional [String] account_name
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
      when :index, :search, :search_for_select, :update
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
