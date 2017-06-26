class NewEmail < StringAttribute

  before_validation :strip_whitespace
  before_save :normalize_email
  before_update :update_contact_in_mailchimp
  before_destroy :delete_contact_from_mailchimp

  validates :string_value, :email_format => {:message => "bad email format"}

  def masked_value
    string = self.string_value
    string.gsub(/.*(?=@)/).first.gsub(/(\w)/,"#") + string.gsub(/(?=@).*/).first
  end

  private
  def normalize_email
    string_value.downcase!
  end

  def strip_whitespace
  	self.string_value = self.string_value.try :strip
  end

  def update_contact_in_mailchimp
    if self.primary_changed?
      if self.primary_was == true
        contact.delete_contact_from_mailchimp(self.string_value)
      elsif self.primary == true
        contact.add_contact_to_mailchimp(self.string_value)
      end
    elsif self.primary? && self.string_value_changed?
      contact.update_contact_in_mailchimp(self.string_value_was)
    end
  end

  def delete_contact_from_mailchimp
    if self.primary?
      contact.delete_contact_from_mailchimp(self.string_value_was)
    end
  end
end
