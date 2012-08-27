class Identification < ContactAttribute
  field :category
  field :value

  validates :value, :presence => true, :uniqueness => {:scope => :category}
  validates :category, :presence => true, :uniqueness => {:scope => :contact}

  before_validation :check_value_uniqueness
  before_save :ensure_public

  def check_value_uniqueness
    return if _parent.nil?
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

  def ensure_public
    self.public = true unless self.public?
  end
end
