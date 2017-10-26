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

  
  attr_accessor :value

  validates :value, :presence => true

  before_save :assign_owner

  # order of call of these two is important!
  before_save :ensure_only_one_primary
  before_save :ensure_at_least_one_primary

  # Returns ContactAttributes visible to account
  #
  # IF :include_masked is used then it can't be further chained as it will return an Array
  #
  # @param [Account] account
  # @param [Hash] options
  # @option [TrueClass] include_masked
  #
  # if :include_masked is used
  #    @return [Array]
  # else
  #    @return [Criteria]
  def self.for_account(account, options = {})
    if options[:include_masked]

      # get attributes
      attrs = self.any_of({account_id: account.id},{public: true},{type: "NewTelephone"},{type: "NewEmail"})
      
      # remove repeated telephones keeping owned version
      values = self.any_of({account_id: account.id},{public: true},{type: "NewTelephone"},{type: "NewEmail"}).collect(&:string_value)
      repeated_values = values.group_by{|e| e}.keep_if{|_, e| e.length > 1}.keys
      attrs_without_repetition = attrs.reject{|a| a.is_a?(NewTelephone) && a.value.in?(repeated_values) && a.account_id!=account.id}

      # mask non-public phones not belonging to given account
      attrs_without_repetition.map do |a|
        if (a.is_a?(NewTelephone) || a.is_a?(NewEmail)) && !a.public? && a.account_id!=account.id
          a.mask_value!
        else
          a
        end
      end
    else
      any_of({account_id: account.id}, { public: true})
    end
  end


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
