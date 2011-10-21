class Identification < ContactAttribute
  field :category
  field :value

  validates :value, :presence => true, :uniqueness => {:scope => :category}
  validates :category, :presence => true, :uniqueness => {:scope => :contact}

  before_validation :check_value_uniqueness

  def check_value_uniqueness
    return if _parent.nil?
    if Contact.where({'_id' => {'$ne' =>contact._id}}).and({'contact_attributes.value' => value}).and({'contact_attributes.category' => category}).exists?
      errors.add(
            :value,
            :taken
          )
    end
  end
end