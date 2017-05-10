# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class NewAccount < ActiveRecord::Base
  self.table_name = "accounts"

  has_many :owned_contacts, foreign_key: :owner_id, class_name: "NewContact"

  has_many :account_contacts, foreign_key: :account_id
  has_many :contacts, through: :account_contacts, class_name: "NewContact"

  validates :name, presence: true, uniqueness: true, existance_on_padma: true
  
  def padma
    PadmaAccount.find_with_rails_cache(name) if name
  end

end