class Email < ContactAttribute

  before_validation :strip_whitespace
  before_save :normalize_email
  before_save :update_contact_in_mailchimp
  before_destroy :delete_contact_from_mailchimp

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

  def update_contact_in_mailchimp
    if self.primary? && self.value_changed?
      contact.update_contact_in_mailchimp(self.value_was)
    end
  end

  def delete_contact_from_mailchimp
    if self.primary?
      contact.delete_contact_from_mailchimp(self.value_was)
    end
  end
end
