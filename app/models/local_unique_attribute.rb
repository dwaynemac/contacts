class LocalUniqueAttribute
  include Mongoid::Document
  include Mongoid::Timestamps
  include AccountNameAccessor

  field :value

  validates :value, :presence => true

  embedded_in :contact
  referenced_in :account

  validates_presence_of :account
  validates_uniqueness_of :account_id, scope: [:contact_id, '_type']  # scope: :contact_id might not be needed since it's embedded

  %W(coefficient local_status).each do |lua|
    scope lua.pluralize, where: { _type: lua.camelcase }
  end

  # Override as_json to change :account_id for :account_name
  def as_json(options)
    super({methods: [:_type, :account_name], except: :account_id}.merge(options||{}))
  end

  def public?
    false
  end

end