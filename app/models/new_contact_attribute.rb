##
# @restful_api v0
#
# = Contact Attribute
#
# This is an abstraction for all attributes like Email, Address, Telephone, Identification, etc.
#
# == Primary attributes
#
# For each contact, for each attribute type and each account there is *one* primary attribute
#
# @property [String] category
class NewContactAttribute < ActiveRecord::Base
  self.table_name = "contact_attributes"

  has_objectid_columns :contact_id

  belongs_to :account, class_name: "NewAccount"

  belongs_to :contact, class_name: "NewContact"

  TYPES = %W(email telephone address custom_attribute date_attribute identification occupation attachment social_network_id)

  attr_accessor :value

  validates :value, :presence => true

  before_save :assign_owner

  # order of call of these two is important!
  before_save :ensure_only_one_primary
  before_save :ensure_at_least_one_primary

  TYPES.each do |k|
    scope k.pluralize, where( type: "New" + k.camelcase )
  end
  scope :mobiles, where(type: 'NewTelephone', category: 'mobile' )

  def mask_value!
    self.value = self.masked_value
    self.readonly!
    self
  end

  protected

  def ensure_only_one_primary
    if self.primary_changed? && self.primary?
      context = self.contact.contact_attributes
      context = context.where('id NOT IN (?)',[self.id]) if self.id.present?
      context.where(type: self.type, account_id: self.account_id).update_all(:primary => false)
    end
  end

  def ensure_at_least_one_primary
    return if self.contact.nil?
    if self.contact.contact_attributes.where(type: self.type, account_id: self.account_id, primary: true).count == 0
      self.primary = true
    end
  end

  def assign_owner
    self.account = self.contact.owner if self.account.blank? && self.contact.owner.present?
  end

  def contact_id
    contact.id
  end
end
