class Contact
  include Mongoid::Document
  #include Mongoid::Timestamps
  #include Mongoid::Versioning

  embeds_many :contact_attributes

  field :first_name
  field :last_name

  belongs_to :owner, :class_name => "Account"

  validates :first_name, :presence => true

  def full_name
    "#{first_name} #{last_name}"
  end

end