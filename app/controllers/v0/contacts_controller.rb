require "#{Rails.root}/app/controllers/v0/concerns/contacts_scope"
require 'oj'
# @restful_api v0
class V0::ContactsController < V0::ApplicationController
  include V0::Concerns::ContactsScope

  authorize_resource
  skip_authorize_resource only: :search_for_select

  before_filter :set_list
  before_filter :set_scope, except: [:create]
  before_filter :refine_scope, only: [:index, :search]
  before_filter :convert_last_seen_at_to_time, only: [:update]
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
  # @optional [Array] order_ids will be used as reference for ordering returned contacts if respect_ids_order given
  # @optional [Boolean] respect_ids_order. If present then returned contacts will be ordered as order_ids or ids 
  # @optional [String] account_name will scope contacts to this account
  # @optional [String] list_name scope to this list. Will be ignored if no :account_name is given.
  # @optional [Integer] page will return this page (default: 1)
  # @optional [Integer] per_page will paginate contacts with this amount per page (default: 10)
  # @optional [String] full_text will make a full_text search with this string.
  # @optional [Array] select return only selected contact attributes.
  #                   - :full_name is an alias for :first_name AND :last_name
  #                   - other: :first_name, :last_name, :telephone, :email, etc.
  #                   if you specify an attribute as a key value pair.
  #                   key will be interpreted as attribute name and value as reference date to get value from.
  # @optional [Hash] where Mongoid where selector with additional keys -> :email, :telephone, :address, :local_status, :date_attribute
  # @optional [Array] sort Array in the form [attribute,order]. Eg: [:first_name, :asc]
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
    total = 0
    measure('count.index.contacts_controller') do
      total = @scope.count
    end

    if params[:respect_ids_order]
      ids = stringified_order_ids
      contact_ids = @scope.only(:_id).map{|c| c._id.to_s }
      # TODO [ ] si mande solo algunos de los order_ids puede haber muchos contact_ids que
      # no esten incluidos. por ejemplo si todos los primeros ids del order eran mujeres pero estoy filtrando hombres.

      # intersecting will return contacts_ids in ids order ( because we put ids first )
      # we then concatenate missing ids in the end
      ordered_ids = (ids & contact_ids) + (contact_ids - ids)

      current_page_ids = Kaminari::paginate_array(ordered_ids).page(params[:page] || 1).per(params[:per_page] || 10)

      @contacts = Contact.find(current_page_ids) # We can't be sure that Mongoid.find preserves order (ActiveRecord doesnt)
      @contacts.sort!{|a,b| current_page_ids.index(a._id.to_s) <=> current_page_ids.index(b._id.to_s) }
    else
      @scope = @scope.order_by(normalize_criteria(params[:sort].to_a)) if params[:sort].present?
      @contacts = @scope.page(params[:page] || 1).per(params[:per_page] || 10)
    end

    measure('render_json.index.contacts_controller') do
      measure('build_hash.render_json.index.contacts_controller') do
        as_json_params = {
          select: params[:select],
          account: @account,
          except_linked: true,
          except_last_local_status: true,
          include_history: ( params[:include_history] == "true" )
        }

        if params[:only_name].present?
          as_json_params[:mode] = 'only_name'
        elsif params[:select].nil? || params[:global] == "true"
          as_json_params[:mode] = 'all'
        else
          as_json_params[:mode] = 'select'
        end
        if params[:global] = "true"
          as_json_params[:include_masked] = true
        end
        
        measure('initialize_collection_hash.build_hash.render_json.index.contacts_controller') do
          @collection_hash = @contacts
        end
        measure('select_columns_collection_hash.build_hash.render_json.index.contacts_controller') do
          @collection_hash = @collection_hash.only(select_columns(params[:select])) unless params[:global] == "true" # TODO compatible with respect_ids_order ?
        end
        measure('as_json_colletion_hash.build_hash.render_json.index.contacts_controller') do
          @collection_hash = @collection_hash.as_json(as_json_params)
        end
      end
      measure('serializing.render_json.index.contacts_controller') do
        @json = Oj.dump({ 'collection' => @collection_hash, 'total' => total})
      end
      measure('rendering.render_json.index.contacts_controller') do
        response.headers['Content-type'] = 'application/json; charset=utf-8'
        render :json => @json
      end
    end
  end

  def search_for_select
    authorize! :read, Contact
    @scope = @scope.csearch(params[:full_text]) if params[:full_text].present?
    @scope = @scope.api_where(params[:where], @account.try(:id))   if params[:where].present?
    @scope = @scope.order_by(normalize_criteria(params[:sort].to_a)) if params[:sort].present?
    if params[:nids]
      params[:nids] = [params[:nids]] if params[:nids].is_a?(String)
      @scope = @scope.not_in(_id: params[:nids])
    end

    total = @scope.count
    @contacts = @scope.page(params[:page] || 1).per(params[:per_page] || 10)

    respond_to do |format|
      as_json_params =  {
        account: @account,
        except_linked:true,
        except_last_local_status: true,
        only_name: params[:only_name].present?
      }
      
      if params[:only_name].present?
        as_json_params[:mode] = 'only_name'
      else
        as_json_params[:mode] = 'select'
      end
      
      format.js { render :json => { :collection => @contacts, :total => total}.as_json(as_json_params), :callback => params[:callback] }
    end    
  end  

  ##
  # Returns JSON list of contacts
  # similar to contact of given id
  # @url /v0/contacts/:id/similar
  # @action GET
  #
  # @required [String] id contact_id
  # @optional [String] account_name
  def similar
    @contact = @scope.find(params[:id])
    @similar = @contact.similar

    as_json_params = {
      account: @account,
      select: [
        :full_name,
        :email,
        :telephone,
        :status,
        :local_status,
        :identification
      ]
    }

    render json: {
      collection: @similar.as_json(as_json_params),
      total: @similar.count
    }
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
  # @optional [Array] select return only selected contact attributes. :full_name is an alias for :first_name AND :last_name other: :first_name, :last_name, :telephone, :email, :occupation etc. if you specify an attribute as a key value pair. key will be interpreted as attribute name and value as reference date to get value from.
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
    measure 'find_contact.show.contacts_controller' do
      @contact = @scope.find(params[:id])
    end
    as_json_params = {
      select: params[:select],
      account: @account,
    }

    as_json_params[:include_masked] = params[:include_masked].nil?? default_masked : params[:include_masked].to_s == "true"

    if params[:select].nil? || params[:select] == 'all'
      as_json_params[:mode] = 'all'
      params.delete :select
      as_json_params.delete :select
    else
      as_json_params[:mode] = 'select'
    end

    json = nil
    measure 'to_json.show.contacts_controller' do
      json = @contact.as_json(as_json_params)
    end
    render json: json
  end

  ##
  # Returns JSON for a contact finding by kshema_id
  # @see show
  #
  # @url /v0/contacts/by_kshema_id
  # @action GET
  # @url /v0/accounts/:account_name/contacts/by_kshema_id
  # @action GET
  #
  # @required [String] kshema_id
  # @optional [String] account_name
  def show_by_kshema_id
    if params[:kshema_id].blank?
      render json: 'kshema_id missing', status: 400
    else
      @contact = @scope.where(kshema_id: params[:kshema_id]).first
      if @contact
        render json: @contact.as_json(select: params[:select], account: @account)
      else
        render json: 'Not Found', status: 404
      end
    end
  end
  
  ##
  # Returns JSON for a contact finding by slug
  # @see show
  #
  # @url /v0/contacts/by_slug
  # @action GET
  #
  # @required [String] slug
  def show_by_slug
    if params[:slug].blank?
      render json: 'slug missing', status: 400
    else
      @contact = @scope.where(slug: params[:slug]).first
      if @contact
        render json: @contact.as_json(select: [:id,
                                               :full_name,
                                               :level,
                                               :identification,
                                               :owner_name,
                                               :avatar,
                                               :status
                                               ],
                                      account: @contact.owner)
      else
        render json: 'Not Found', status: 404
      end
    end
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
  # @optional [Boolean] find_or_create
  # @optional [String] id . if find_or_create is given and id is present will find contact by given id
  # @options  [Boolean] dont_save_name . wont copy name into the contact. used for dumping attributes
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
    @new_tag_names = params[:contact].delete(:new_tag_names)
    
    @contact = Contact.new(params[:contact].merge({
      request_account_name: params[:account_name],
      request_username: params[:username]
    }))
    @contact.owner = @account if @account
    
    # This is needed because contact_attributes are first created as ContactAttribute instead of _type!!
    @contact = @contact.reload unless @contact.new_record?

    if params[:find_or_create]

      existing_contact = if params[:id]
        Contact.find(params[:id])
      else
        duplicates = @contact.similar(ignore_name: true)
        duplicates.first
      end

      if existing_contact

        copy_data_to_existing_contact(@contact,existing_contact)

        # Work on existing contact
        @contact = existing_contact
      end
    else
      #set again check duplicates virtual attribute (lost after reloading)
      @contact.check_duplicates = params[:contact][:check_duplicates]
    end
      
    if @contact.save
      
      if @new_tag_names
        # this change is persisted in the moment
        @contact.add_tags_by_names @new_tag_names
      end

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
  # @optional [Boolean] ignore_validation saved contact without validating.
  #                     currently only valid for local_status attribute
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

    res = if params[:ignore_validation]
      set_whitelisted_attributes
      @contact.save validate: false
    else
      @contact.update_attributes(params[:contact])
    end
    if res
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
    if @account && @account.link(@contact)
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
    elsif params[:total_destruction] == "true"
      @contact.destroy
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
    if params[:ids].blank?
      render json: 'specify :ids', status: 400
    else
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
  end

  private

  def stringified_order_ids
    # use :order_ids or :ids if not available
    order_ids = if params[:order_ids].present?
      params[:order_ids]
    elsif params[:ids].present?
      params[:ids]
    end

    #stringify
    if order_ids && order_ids[0].is_a?(BSON::ObjectId)
      order_ids.map &:to_s
    else
      order_ids
    end
  end

  
  # if request is for account
  # where contact is student
  #               or former_student
  # dont include masked attributes
  def default_masked
    if @account.present?
      local_status = @contact.local_value_for_account('local_status',@account.id).try(:to_sym)
      !local_status.in?([:student, :former_student])
    else
      true
    end
  end

  # Converts
  #   local_status -> local_status_for_CurrentAccountName
  #   coefficient  -> coefficient_for_CurrentAccountName
  # If there is no current_account (@account) then key is removed from attributes hash.
  def convert_local_attributes
    %w(local_status coefficient local_teacher last_seen_at).each do |la|
      if @account
        if params[:contact][la]
          params[:contact]["#{la}_for_#{@account.name}"] = params[:contact].delete(la)
        end
      else
        params[:contact].delete(la)
      end
    end
  end

  def convert_last_seen_at_to_time
    if params[:contact]["last_seen_at"]
      params[:contact]["last_seen_at"] = Time.parse(params[:contact]["last_seen_at"])
    end
  end

  def select_columns(select_params)
    return nil if select_params.nil?
    r = [:_id]
    select_params.each do |param|
      case 
        when %w(local_status coefficient local_teacher observation last_seen_at local_unique_attributes local_statuses).include?(param)
          r << :local_unique_attributes
        when %w(email telephone birthday address contact_attributes).include?(param)
          r << :contact_attributes
        when %w(full_name).include?(param)
          r << :first_name
          r << :last_name
        else
          r << param.to_sym
      end
    end
    r.uniq
  end

  def set_scope
    @scope = case action_name.to_sym
      when :index, :search, :search_for_select, :update
        (@account.present? && !params[:global]) ? (@list.present?? @list.contacts : @account.contacts ) : Contact
      when :destroy, :destroy_multiple
        @account.present?? @account.contacts : Contact
      else
        Contact
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

  # Sort by normalized fields
  def normalize_criteria(criteria)
    if criteria.is_a? Array then
      criteria.map! { |crit| normalize_criteria crit }
    elsif /^(first_name|last_name)$/.match(criteria) then
      criteria = 'normalized_' + criteria
    end
    criteria
  end

  def set_whitelisted_attributes
    params[:contact].select{|k,v| k =~ /local_status/}.each do |k,v|
      @contact.send("#{k}=",v)
      @contact.set_status
    end
    params[:contact].select{|k,v| k =~ /local_teacher/}.each do |k,v|
      @contact.send("#{k}=",v)
      @contact.set_global_teacher
    end
    params[:contact].select{|k,v| k =~ /last_seen_at|level|first_enrolled_on|derose_id|professional_training_level|in_professional_training|observation/}.each do |k,v|
      @contact.send("#{k}=",v)
    end
  end

  ##
  #
  # identifies block with given key in appsignal
  def measure(key)
    ActiveSupport::Notifications.instrument(key) do
      yield
    end
  end

  def copy_data_to_existing_contact(contact,existing_contact)
    request_account = Account.where(name: params[:account_name]).first

    # Copy Contact Attributes
    contact.contact_attributes.select do |ca|
      # ignore attributes already existing in contact
      existing_contact.contact_attributes
                       .where(_type: ca._type,
                              value: ca.value,
                              account_id: request_account.id)
                       .empty?
    end.each do |ca|
      ca.account = request_account
      existing_contact.contact_attributes << ca.clone
      existing_contact.contact_attributes.last._type = ca._type # clone wont copy _type
    end


    unless params[:dont_save_name]
      # set last_name if blank
      if existing_contact.last_name.blank?
        existing_contact.last_name = contact.last_name
      else
        unless contact.last_name.blank?
          # save new lastname as custom_attribute
          existing_contact.contact_attributes << CustomAttribute.new(
            name: 'other last name',
            value: contact.last_name,
            account: request_account
          )
        end
      end
    end

    unless params[:dont_save_name]
      # save new firstname as custom_attribute
      unless contact.first_name.blank?
        existing_contact.contact_attributes << CustomAttribute.new(
          name: 'other first name',
          value: contact.first_name,
          account: request_account
        )
      end
    end

    # Copy Local Statuses
    contact.local_statuses.each do |ls|
      if existing_contact.local_statuses.where(:account_id => ls.account_id).count == 0
        existing_contact.local_unique_attributes << ls
      end
    end

    # Copy coefficient
    contact.coefficients.each do |lc|
      if existing_contact.coefficients.where(:account_id => lc.account_id).count == 0
        existing_contact.local_unique_attributes << lc
      end
    end

    existing_contact.request_account_name = contact.request_account_name
    existing_contact.request_username = contact.request_username

    # Link existing contact to request account
    unless existing_contact.linked_to?(request_account)
      existing_contact.accounts << request_account
    end

    # Owner was set manually, transfer
    if contact.new? && contact.owner_name.present?
      # wont relinquish ownership of student
      unless existing_contact.status == :student
        existing_contact.owner_name = contact.owner_name 
      end
    end

  end
end
