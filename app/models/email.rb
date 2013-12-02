class Email < ContactAttribute

  before_validation :strip_whitespace
  before_save :normalize_email

  field :category

  attr_accessor :allow_duplicate

  validates :value, :email_format => {:message => "bad email format"}, :email_uniqueness => true

  private
  def normalize_email
    value.downcase!
  end

  def strip_whitespace
  	self.value = self.value.strip
  end
end
