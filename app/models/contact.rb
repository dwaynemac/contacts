class Contact
  include Mongoid::Document
  #include Mongoid::Timestamps
  #include Mongoid::Versioning

  embeds_many :contact_attributes

  field :first_name
  field :last_name

  referenced_in :account

  validates :first_name, :presence => true

  def full_name
    "#{first_name} #{last_name}"
  end

end