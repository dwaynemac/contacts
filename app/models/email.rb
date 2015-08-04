class Email < ContactAttribute

  before_validation :strip_whitespace
  before_save :normalize_email

  field :category

  validates :value, :email_format => {:message => "bad email format"}

  def masked_value
    string = self.value
    string.gsub(/.*(?=@)/).first.gsub(/(\w)/,"#") + string.gsub(/(?=@).*/).first
  end


  private
  def normalize_email
    value.downcase!
  end

  def strip_whitespace
  	self.value = self.value.try :strip
  end
end
