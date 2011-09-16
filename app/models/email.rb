class Email < ContactAttribute
  field :category
  field :value

  validates :value, :presence => true, :email_format => true, :email_uniqueness => true
end