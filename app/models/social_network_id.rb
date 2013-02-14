class SocialNetworkId < ContactAttribute
  field :category
  field :value

  validates :value, :presence => true, :uniqueness => {:scope => :category}, :unless => :check_duplicates
  validates :category, :presence => true, :uniqueness => {:scope => :contact}, :unless => :check_duplicates

  before_validation :check_value_uniqueness

  def check_value_uniqueness
    return if _parent.nil? || !_parent.check_duplicates
    if Contact.where({'_id' => {'$ne' =>contact._id}}).and({'contact_attributes.value' => value}).and({'contact_attributes.category' => category}).exists?
      errors.add(
            :value,
            :taken
          )
    end
  end

  def get_normalized_value
    self.value.gsub(/[\.\-_\s\/]/,'')
  end

  private

  def check_duplicates
    _parent.check_duplicates
  end
end
