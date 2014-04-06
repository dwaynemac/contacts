class ContactSerializer
  
  def initialize(contact)
    @contact = contact
  end

  def serialize(ops = {})
    ActiveSupport::Notifications.instrument('as_json.contact') do
      
      # Initializing hash with default values
      ops.reverse_merge!({select: [:first_name, :last_name]})
      @json = {}

      if ops[:select] == 'only_name'
        serialize_only_name
      elsif ops[:select] == 'all'
        serialize_all
      else
        serialize_select
      end

    end
  end

  private

  def serialize_only_name
    @json[:id] = @contact.id
    @json[:name] = @contact.full_name
  end

  def serialize_all
  end

  def serialize_select

  end

end
