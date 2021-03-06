class ContactSerializer
  
  DEFAULT_SELECT = [:_id, :first_name, :last_name]
  ##
  # Contact Serializer
  #
  # @param [Contact] contact 
  # @param [String] attributes[:mode] select, all or only_name
  # @param [Array] attributes[:select] select attributes
  # @param [Account] attributes['account'] account
  #
  # == Valid options for select.
  #   - first_name
  #   - last_name
  #   - full_name
  #   - id
  #   - gender
  #   ... 
  #
  #
  # If account_name has been indicated
  #   - email
  #   - telephone
  #   - contact_attributes
  #   - local_teacher
  #   - local_status
  #   - 
  #   ...
  #
  # == Modes
  #   select
  #     serializes contacts with selected attributes|
  #
  #   all
  #     serialized contact with all its attributes
  #
  #   only_name
  #     serializes contact in 2 fields.
  #         :id
  #         :name (full_name)
  def initialize(attributes = {})
    @contact = attributes[:contact]

    if attributes[:select].blank?
      self.select = DEFAULT_SELECT
    else
      if attributes[:select].is_a?(Array)
        self.select = attributes[:select].map{|s| s.is_a?(String)? s.to_sym : s }
      else
        # For backward compatibility
        if attributes[:select] == 'all'
          attributes[:mode] = 'all'
          self.select = DEFAULT_SELECT
        end
      end
    end

    @mode = attributes[:mode] || 'select'
    self.account= attributes[:account]
    @include_masked = attributes[:include_masked]
    @include_history = attributes[:include_history]
    @except = attributes[:except]
  end

  def select=(s)
    @select = s
  end

  def account=(a)
    @account = a
  end

  # returns a hash with corresponding keys according to options
  # all keys are Strings
  def serialize
    @json = {}
    ActiveSupport::Notifications.instrument('as_json.contact') do
      if @mode == 'only_name'
        build_hash_only_name
      elsif @mode == 'all' 
        build_hash
      elsif @mode == 'select'
        prepare_select
        build_hash
        add_historic_values
      end
    end
    @json
  end

  private

  def build_hash_only_name
    @json['id'] = @contact.id
    @json['name'] = @contact.full_name
  end
  
  def build_hash
    ActiveSupport::Notifications.instrument('build_hash.as_json.contact') do

      ActiveSupport::Notifications.instrument('root_attributes.build_hash.as_json.contact') do
        @json['first_name'] = @contact.first_name if serialize?(:first_name) 
        @json['last_name'] = @contact.last_name if serialize?(:last_name) 
        @json['id'] = @contact.id.to_s if serialize?(:id) 
        @json['_id'] = @contact.id.to_s if serialize?(:_id) 
        @json['kshema_id'] = @contact.kshema_id if serialize?(:kshema_id) 
        @json['derose_id'] = @contact.derose_id if serialize?(:derose_id) 
        @json['slug'] = @contact.slug if serialize?(:slug) 
        @json['first_enrolled_on'] = @contact.first_enrolled_on.to_s if serialize?(:first_enrolled_on) 
        @json['gender'] = @contact.gender if serialize?(:gender) 
        @json['estimated_age'] = @contact.estimated_age if serialize?(:estimated_age) 
        @json['status'] = @contact.status.to_s if serialize?(:status) 
        @json['global_teacher_username'] = @contact.global_teacher_username if serialize?(:global_teacher_username) 
        @json['level'] = @contact.level if serialize?(:level) 
        @json['coefficients_counts'] = @contact.coefficients_counts if serialize?(:coefficients_counts)
        @json['owner_name'] = @contact.owner_name if serialize?(:owner_name)
        @json['in_active_merge'] = @contact.in_active_merge if serialize?(:in_active_merge)
        @json['in_professional_training'] = @contact.in_professional_training if serialize?(:in_professional_training)
        @json['professional_training_level'] = @contact.professional_training_level if serialize?(:professional_training_level)
        @json['avatar'] = @contact.avatar.as_json if serialize?(:avatar)

        @json['created_at'] = @contact.created_at.to_s if serialize?(:created_at) 
        @json['updated_at'] = @contact.updated_at.to_s if serialize?(:updated_at) 
      end

      if serialize?(:local_statuses)
        ActiveSupport::Notifications.instrument('local_statuses.build_hash.as_json.contact') do
          @json['local_statuses'] = @contact.local_statuses.map{ |ls| {
            'account_name' => ls.account_name.to_s,
            'local_status' => ls.value.to_s
          } }
        end
      end

      # we dont use serialize? because this should be false by default, even for select: :all
      if @include_history
        ActiveSupport::Notifications.instrument('include_history.build_hash.as_json.contact') do
          @json['history_entries'] = @contact.history_entries.map do |he|
            {
              "_id" => he._id.to_s,
              "historiable_id" => he.historiable_id.to_s,
              "historiable_type" => he.historiable_type,
              "attribute" => he.attribute.to_s,
              "changed_at" => he.changed_at.to_s,
              "old_value" => he.old_value
            }
          end
        end
      end

      if serialize?(:local_teachers)
        ActiveSupport::Notifications.instrument('local_teachers.build_hash.as_json.contact') do
          @json['local_teachers'] = @contact.local_teachers.map{ |ls| {
            'account_name' => ls.account_name.to_s,
            'local_teacher' => ls.value.to_s
          } }
        end
      end

      ActiveSupport::Notifications.instrument('account_attributes.build_hash.as_json.contact') do
      if @account
        if serialize?(:contact_attributes) || serialize?(:date_attribute)
          @json['contact_attributes'] = @contact.contact_attributes
                                                .for_account(@account, {include_masked: @include_masked})
                                                .as_json
        end
        
        @json['tags'] = @contact.tags.where(account_id: @account.id).as_json if serialize?(:tags)

        %W(local_status coefficient local_teacher observation last_seen_at).each do |local_attribute|
          if serialize?(local_attribute)
            @json[local_attribute] = @contact.local_value_for_account(local_attribute,@account.id).try(:to_s)
          end
        end
        
        unless except?(:except_linked)
          ActiveSupport::Notifications.instrument('linked_bool.account_attributes.build_hash.as_json.contact') do
            @json['linked'] = @contact.linked_to?(@account)
          end
        end
        
        if serialize?(:last_local_status)
          ActiveSupport::Notifications.instrument('last_local_status.account_attributes.build_hash.as_json.contact') do
            @json['last_local_status'] = @contact.history_entries.last_value("local_status_for_#{@account.name}".to_sym)
          end
        end

        if serialize?(:attachments)
          @json['attachments'] = @contact.attachments
                                          .for_account(@account)
                                          .as_json
        end
        
        if serialize?(:telephone)
          telephone = if @account
            @contact.primary_attribute(@account,'Telephone') 
          else
            @contact.global_primary_attribute('Telephone') 
          end
          @json['telephone'] = telephone.value unless telephone.nil?
        end

        if serialize?(:occupation)
          occupation = @contact.occupations.first
          if occupation
            @json['occupation'] = occupation.value
          end
        end

        if serialize?(:birthday)
          birthday = @contact.date_attributes.where(category: 'birthday').first
          @json['birthday'] = birthday.value unless birthday.nil?
        end

        if serialize?(:address)
          address = @contact.primary_attribute(@account, 'Address')
          unless address.nil?
            @json['address'] = address.value
            @json['postal_code'] = address.postal_code
            @json['city'] = address.city
            @json['state'] = address.state
            @json['country'] = address.country
          end
        end

      end
     
      if serialize?(:email)
        email = if @account
          @contact.primary_attribute(@account,'Email')
        else
          @contact.global_primary_attribute('Email')
        end

        @json['email'] = email.value unless email.nil?
      end 
      
      if serialize?(:identification)
        identification = if @account
          @contact.primary_attribute(@account,'Identification') 
        else
          @contact.global_primary_attribute('Identification') 
        end
         
        @json['identification'] = identification.value unless identification.nil?
      end 
        
      end
    end
  end

  def serialize? (attribute)
    if @mode == 'all'
      true
    else
      attribute.to_sym.in?(@select)
    end
  end

  def except? (attribute)
    if @except
      @except[attribute]
    else
      false
    end
  end

  def prepare_select
    # always include id
    @select << :_id unless :_id.in?(@select)
    
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
      @json[attribute.to_s] = @contact.attribute_value_at(attribute, ref_date)
    end
  end
end
