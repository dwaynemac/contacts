class LocalUniqueAttribute < ContactAttribute

  validates_presence_of :account
  validates_uniqueness_of :account_id, scope: [:contact_id, '_type']

  before_validation :never_public

  # @return [String] account name
  def account_name
    self.account.try :name
  end

  # Sets account by name
  # won't create account if inexistant
  def account_name=(name)
    self.account = Account.where(name: name).first
  end

  # Override as_json to change :account_id for :account_name
  def as_json(options)
    super({methods: [:account_name], except: :account_id}.merge(options||{}))
  end

  def public?
    false
  end

  private
  def never_public
    self.public = false
    return true
  end

end
