# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class AccountContact < ActiveRecord::Base
  
  belongs_to :account, :class_name => 'NewAccount'
  belongs_to :contact, :class_name => 'NewContact'

  has_objectid_columns :contact_id

  validates :account, presence: true
  validates :contact, presence: true

end