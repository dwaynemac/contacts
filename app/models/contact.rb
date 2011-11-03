class Contact
  include Mongoid::Document
  #include Mongoid::Timestamps
  #include Mongoid::Versioning

  accepts_nested_attributes_for :contact_attributes

  before_create :assign_owner
  before_save :update_lists_contacts

  embeds_many :contact_attributes, :validate => true

  field :first_name
  field :last_name

  belongs_to :owner, :class_name => "Account"
  references_and_referenced_in_many :lists

  validates :first_name, :presence => true

  validates_associated :contact_attributes

  accepts_nested_attributes_for :contact_attributes

  def full_name
    "#{first_name} #{last_name}"
  end

  def as_json(options={})
    account = options.delete(:account) if options
    options.merge!({:except => :contact_attributes}) if account
    json = super(options)
    json[:contact_attributes] = self.contact_attributes.for_account(account) if account
    json
  end

  protected

  def assign_owner
    self.owner = lists.first.account unless lists.empty?

    # Callbacks arent called when mass-assigning nested models.
    # Iterate over the contact_attributes and set the owner.
    if self.owner.present?
      contact_attributes.each {|att| att.account = owner}
    end
  end

  def update_lists_contacts
    if self.owner && self.lists.empty?
      self.lists << self.owner.lists.first
    end
  end
end