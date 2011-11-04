class Email < ContactAttribute
  field :category

  validates :value, :email_format => true, :email_uniqueness => true
end