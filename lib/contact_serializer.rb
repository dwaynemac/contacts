class ContactSerializer
  
  def initialize(contact)
    @contact = contact
  end

  def serialize(options = {})
    ActiveSupport::Notifications.instrument('as_json.contact') do
      
      @ops = options
      
      # Initializing hash with default values
      @ops.reverse_merge!({select: [:first_name, :last_name]})
      @json = {}

      if @ops[:select] == 'only_name'
        serialize_only_name
      elsif @ops[:select].nil? || @ops[:select] == 'all'
        serialize_all
      else
        serialize_specific_attributes
      end
      @json
    end
  end

  private

  def serialize_only_name
    @json[:id] = @contact.id
    @json[:name] = @contact.full_name
  end

  def serialize_all

    @ops = @ops.merge({
      except: [:owner_id, :history_entries],
      methods: [
        :owner_name,
        :local_statuses,
        :coefficients_counts,
        :in_active_merge
      ]
    })
    
    account = @ops[:account] 
    if account
      @ops = @ops.merge({
        except: [
          :contact_attributes,
          :local_unique_attributes,
          :tag_ids
        ]
      }) {|key, old_val, new_val| old_val + new_val}
    end

    @json = @contact.as_json(@ops)
    
    if account
      @json[:contact_attributes] = @contact.contact_attributes.for_account(account, @options)
      @json[:tags] = @contact.tags.where(account_id: account.id)
      %w{local_status coefficient observation local_teacher}.each do |local_attribute|
        @json[local_attribute] = @contact.send("#{local_attribute}_for_#{account.name}")
      end

      unless options[:except_linked]
        @json[:linked] = @contact.linked_to?(account)
      end

      unless [:except_last_local_status]
        @json[:last_local_status] = @contact.history_entries.last_value("local_status_for_#{account.name}".to_sym)
      end

    end 
  end

  def serialize_specific_attributes

  end

end
