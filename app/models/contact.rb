class Contact
  include Mongoid::Document
  #include Mongoid::Timestamps
  #include Mongoid::Versioning

  embeds_many :contact_attributes

  field :first_name
  field :last_name

  belongs_to :owner, :class_name => "Account"
  references_and_referenced_in_many :lists

  validates :first_name, :presence => true

  before_create :assign_owner

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
  end
end