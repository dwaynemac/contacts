# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class ContactImport < ActiveRecord::Base
  
  belongs_to :import, :class_name => 'NewImport'
  belongs_to :contact, :class_name => 'NewContact'

  has_objectid_columns :contact_id

  validates :import, presence: true
  validates :contact, presence: true

end