class Identification < ContactAttribute
  field :category
  field :value

  validates :value, :presence => true, :uniqueness => {:scope => :category}, :unless => :check_duplicates
  validates :category, :presence => true, :uniqueness => {:scope => :contact}, :unless => :check_duplicates

  before_validation :check_value_uniqueness
  before_save :ensure_public

  def check_value_uniqueness
    return if _parent.nil? || !_parent.check_duplicates
    r = Contact.where({'_id' => {'$ne' =>contact._id}})
              .and( contact_attributes: { '$elemMatch' => {
                      value: value,
                      category: category }})
    if r.count > 0
      errors[:value] << I18n.t('errors.messages.is_not_unique')
      contact.errors[:possible_duplicates] << r.map {|c| c.minimum_representation}
    end
  end

  def get_normalized_value
    self.value.gsub(/[\.\-_\s\/]/,'')
  end

  private

  def check_duplicates
    _parent.check_duplicates
  end

  def ensure_public
    self.public = true unless self.public?
  end
end
