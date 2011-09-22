# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class Account
  include Mongoid::Document

  field :name

  has_many :contacts, :foreign_key => :owner_id

  validates :name, :presence => true, :uniqueness => true, :existance_on_padma => true
end
