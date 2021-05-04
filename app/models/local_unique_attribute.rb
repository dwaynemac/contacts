class LocalUniqueAttribute
  include Mongoid::Document
  include Mongoid::Timestamps
  include AccountNameAccessor

  field :value

  embedded_in :contact
  referenced_in :account

  validates_presence_of :account
  validates_uniqueness_of :account_id, scope: [:contact_id, '_type']  # scope: :contact_id might not be needed since it's embedded

  scope :for_account, ->(account_id){ where(account_id: account_id) }
  #after_save :touch_contact

  %W(coefficient local_status local_teacher observation last_seen_at).each do |lua|
    scope lua.pluralize, where( _type: lua.camelcase )
  end

  # Override as_json to
  #  - change :account_id for :account_name
  #  - add :_type
  def as_json(options)
    options = {} if options.nil?
    options[:except]  = [:account_id] + (options[:except]||[])
    options[:methods] = [:_type, :account_name] + (options[:methods]||[])
    super(options)
  end

  def public?
    false
  end

  def touch_contact
    #contact.touch
  end
end
