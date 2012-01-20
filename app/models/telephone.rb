class Telephone < ContactAttribute

  field :category

  before_validation :camelize_category

  validates_numericality_of :value, only_integer: true, greater_than: 0
  # validates_format_of :value, with: /^\d[\d| |\-]{4,16}.*\d$/

  validate :mobile_uniqueness

  def masked_value
    string = self.value
    string.gsub(/[^\d]/,"").gsub(/^(\d{4}).*/,'\1')+string.gsub(/[^\d]/,"").gsub(/^\d{4}/,"").gsub(/\d/,"#")
  end

  private

  def mobile_uniqueness
    return unless category.to_s.camelcase == 'Mobile'

    r = Contact.excludes(_id: self.contact._id).where(
                       'contact_attributes._type' => 'Telephone',
                       'contact_attributes.category' => /Mobile/i,
                       'contact_attributes.value' => value )

    errors[:value] << "mobile is not unique" if r.count > 0
  end

  def camelize_category
    self.category = self.category.to_s.camelcase
  end

end