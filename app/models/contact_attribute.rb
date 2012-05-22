##
# = Contact Attribute
#
# This is an abstraction for all attributes like Email, Address, Telephone, Identification, etc.
#
# == Primary attributes
#
# For each contact, for each attribute type and each account there is *one* primary attribute
class ContactAttribute
  include Mongoid::Document
  include ReadOnly
  include AccountNameAccessor

  field :public, type: Boolean
  field :value, type: String
  field :primary, type: Boolean

  validates :value, :presence => true

  embedded_in :contact

  referenced_in :account

  before_save :assign_owner

  # order of call of these two is important!
  before_save :ensure_only_one_primary
  before_save :ensure_at_least_one_primary

  # - replaces :account_id with :account_name
  # - adds :_type, :contact_id
  #
  # @param options [Hash]
  def as_json(options={})
    options = {} if options.nil?
    options[:methods] = [:_type, :contact_id, :account_name] + ( options[:methods].try(:to_a) || [])
    options[:except]  = [:account_id] + ( options[:except].try(:to_a) || [])

    super(options)
  end

  %W(email telephone address custom_attribute date_attribute).each do |k|
    scope k.pluralize, where( _type: k.camelcase )
  end
  scope :mobiles, where(_type: 'Telephone', category: 'mobile' )

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
      attrs = self.any_of({account_id: account.id},{public: true},{_type: "Telephone"})

      # remove repeated telephones keeping owned version
      value_counts = self.any_of({account_id: account.id},{public: true},{_type: "Telephone"}).only(:value).aggregate
      repeated_values = value_counts.map{|k,v| k if v>1}
      attrs_without_repetition = attrs.reject{|a| a.is_a?(Telephone) && a.value.in?(repeated_values) && a.account_id!=account.id}

      # mask non-public phones not belonging to given account
      attrs_without_repetition.map do |a|
        if a.is_a?(Telephone) && !a.public? && a.account_id!=account.id
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
      set_primary
      self.contact.contact_attributes.not_in(_id: [self._id]).where(_type: self._type, account_id: self.account_id).each do |ca|
        ca.update_attribute(:primary, false)
      end
    end
  end

  def ensure_at_least_one_primary
    if self.contact.contact_attributes.where(_type: self._type, account_id: self.account_id).count == 1 # i'm the only one
      set_primary
    end
  end

  def assign_owner
    self.account = self.contact.owner if self.account.blank? && self.contact.owner.present?
  end

  def contact_id
    contact.id
  end

  def set_primary
    self.contact[self._type.to_sym] = self.value
    self.primary = true
  end
end
