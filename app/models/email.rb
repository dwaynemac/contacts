class Email < ContactAttribute

  before_save :normalize_email

  field :category

  validates :value, :email_format => true, :email_uniqueness => true

  private
  def normalize_email
    value.downcase!
  end
end
