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

  # Links contact with account
  # @param contact [Contact]
  # @return [TrueClass]
  def link(contact)
    contact.accounts << self
    contact.owner = self if contact.owner.nil?
    contact.save
  end

  # Removed this contact from all this accounts lists
  def unlink(contact)
    contact.accounts.delete(self)
    if contact.owner == self
      contact.owner = nil
      contact.cached_owner = nil
    end
    contact.save
  end

  def linked_to?(contact)
    self.id.in?(contact.account_ids)
  end

  def self.name_for_id(id)
    begin
      name = Rails.cache.read(['account_name_by_id',id])
      if name.nil?
        name = NewAccount.find(id).try(:name)
        # using only might use less memory but generates errors
        # of frozen arrays in some specs
        # name = Account.only([:_id,:name]).find(id).try(:name)
        Rails.cache.write(['account_name_by_id',id],name)
      end
      return name
    rescue Mongoid::Errors::DocumentNotFound => e
     return nil 
    end
  end

end