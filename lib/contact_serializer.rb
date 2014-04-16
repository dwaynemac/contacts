class ContactSerializer
  
  ##
  # Contact Serializer
  #
  # @param [Contact] contact 
  # @param [String] attributes[:mode] select, all or only_name
  # @param [Array] attributes[:select] select attributes
  # @param [Account] attributes[:account] account
  #
  def initialize(attributes = {})
    @contact = attributes[:contact]
    @mode = attributes[:mode] || 'select'
    @select = attributes[:select] || [:_id, :first_name, :last_name]
    @account = attributes[:account]
    @include_masked = attributes[:include_masked]
  end

  def serialize
    ActiveSupport::Notifications.instrument('as_json.contact') do
      @json = {}

      if @mode == 'only_name'
        build_hash_only_name
      elsif @mode == 'all' 
        build_hash
      elsif @mode == 'select'
        prepare_select
        build_hash
        add_historic_values
      end

      @json
    end
  end

  private

  def build_hash_only_name
    @json[:id] = @contact.id
    @json[:name] = @contact.full_name
  end
  
  def build_hash
    debugger
    @json[:first_name] = @contact.first_name if serialize?(:first_name) 
    @json[:last_name] = @contact.last_name if serialize?(:last_name) 
    @json[:id] = @contact.id if serialize?(:id) 
    @json[:_id] = @contact.id if serialize?(:_id) 
    @json[:gender] = @contact.gender if serialize?(:gender) 
    @json[:estimated_age] = @contact.estimated_age if serialize?(:estimated_age) 
    @json[:status] = @contact.status if serialize?(:status) 
    @json[:global_teacher] = @contact.global_teacher_username if serialize?(:global_teacher) 
    @json[:level] = @contact.level if serialize?(:level) 
    @json[:coefficients_counts] = @contact.coefficients_counts if serialize?(:coefficients_counts)
    @json[:owner_name] = @contact.owner_name if serialize?(:owner_name)
    @json[:check_duplicates] = @contact.check_duplicates if serialize?(:check_duplicates)
    @json[:in_active_merge] = @contact.in_active_merge if serialize?(:in_active_merge)
    @json[:in_professional_training] = @contact.in_professional_training if serialize?(:in_professional_training)

    if @account
      if serialize?(:contact_attributes)
        @json[:contact_attributes] = @contact.contact_attributes.for_account(@account, {include_masked: @include_masked}).as_json
      end
      
      @json[:tags] = @contact.tags.where(account_id: @account.id).as_json if serialize?(:tags)

      %w{local_status coefficient local_teacher observation}.each do |local_attribute|
        @json[local_attribute] = @contact.send("#{local_attribute}_for_#{@account.name}") if serialize?(local_attribute.to_sym)
      end
      
      unless serialize?(:except_linked)
        @json[:linked] = @contact.linked_to?(@account)
      end
      
      unless serialize?('except_last_local_status')
        @json[:last_local_status] = @contact.history_entries.last_value("local_status_for_#{@account.name}".to_sym)
      end
    end
  end

  def serialize? (attribute)
    if @mode == 'all'
      true
    else
      attribute.in?(@select)
    end
  end

  def prepare_select
    # set default value
    if @select.nil?
      @select = [:first_name, :last_name]
    end
    
    # always include id
    @select << :_id unless @select.include? :_id
    
    if @select.include? :full_name
      @select << :first_name
      @select << :last_name
    end

    # symbolize select keys, separate value_at_time attributes.
    # these attributes need some special treatment
    @historic_values = @select.select{|i|i.is_a?(Hash)}
    @select = @select.reject{|i| i.is_a?(Hash) }.map{|i| i.to_sym }
  end

  def add_historic_values
    @historic_values.each do |pair|
      attribute = pair.keys.first
      ref_date = pair[attribute]
      @json[attribute] = @contact.attribute_value_at(attribute, ref_date)
    end
  end
end
