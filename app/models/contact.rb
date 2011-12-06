require 'mongoid/criteria'

class Contact
  include Mongoid::Document
  include Mongoid::Timestamps
  #include Mongoid::Versioning

  include Mongoid::Search

  accepts_nested_attributes_for :contact_attributes

  before_save :assign_owner
  before_save :update_lists_contacts
  before_save :set_status

  embeds_many :contact_attributes, :validate => true

  field :first_name
  field :last_name
  field :avatar
  
  mount_uploader :avatar, AvatarUploader

  VALID_STATUSES = [:student, :former_student, :prospect]
  field :status, type: Symbol
  before_validation :set_status
  validates_inclusion_of :status, :in => VALID_STATUSES, :allow_blank => true

  belongs_to :owner, :class_name => "Account"
  references_and_referenced_in_many :lists

  validates :first_name, :presence => true

  validates_associated :contact_attributes

  accepts_nested_attributes_for :contact_attributes, :allow_destroy => true

  embeds_many :local_statuses
  mount_uploader :avatar, AvatarUploader

  def full_name
    "#{first_name} #{last_name}"
  end

  # defines Contact#emails/telephones/addresses/custom_attributes/etc
  # they all return a Criteria scoping to according _type
  %W(email telephone address custom_attribute).each do |k|
    define_method(k.pluralize) { self.contact_attributes.where(_type: k.camelcase) }
  end

  # @param [Hash] options
  # @option options [Account] account
  # @option options [TrueClass] include_masked
  def as_json(options={})
    account = options.delete(:account) if options
    options.merge!({:except => :contact_attributes}) if account
    json = super(options)
    json[:contact_attributes] = self.contact_attributes.for_account(account, options) if account
    json
  end

  search_in :first_name, :last_name, :contact_attributes => :value

  def update_status!
    self.set_status
    self.save
  end

  protected

  def assign_owner
    self.owner = lists.first.account unless lists.empty?

    # Callbacks arent called when mass-assigning nested models.
    # Iterate over the contact_attributes and set the owner.
    if self.owner.present?
      contact_attributes.each {|att| att.account = owner unless att.account.present?}
    end
  end

  def update_lists_contacts
    if self.owner && self.lists.empty?
      self.lists << self.owner.lists.first
    end
  end

  def set_status
    distinct_statuses = local_statuses.distinct(:status)
    VALID_STATUSES.each do |s|
      if distinct_statuses.include?(s)
        self.status = s
        break
      end
    end
  end
end
