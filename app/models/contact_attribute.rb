class ContactAttribute
  include Mongoid::Document
  #include Mongoid::Timestamps

  field :public, type: Boolean

  embedded_in :contact

  referenced_in :account

  scope :for_account, ->(account) { any_of({:account_id => account.id}, {:public => true}) }
end