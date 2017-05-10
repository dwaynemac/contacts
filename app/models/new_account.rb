# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class NewAccount < ActiveRecord::Base
  self.table_name = "accounts"

  has_many :owned_contacts, :foreign_key => :owner_id, :class_name => "NewContact"

  has_many :account_contacts
  has_many :contacts, :through => :account_contacts

  validates :name, :presence => true, :uniqueness => true
end