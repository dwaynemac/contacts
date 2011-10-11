class ContactAttribute
  include Mongoid::Document
  #include Mongoid::Timestamps

  field :public, type: Boolean

  embedded_in :contact

  referenced_in :account

  scope :for_account, ->(account) { any_of({:account_id => account.id}, {:public => true}) }

  before_create :assign_owner

  protected

  def assign_owner
    self.account = contact.owner if self.account.blank? && contact.owner.present?
  end
end