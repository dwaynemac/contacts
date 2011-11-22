class Telephone < ContactAttribute

  field :category

  before_validation :camelize_category

  validates :value, :numericality => true

  validate :mobile_uniqueness

  def masked_value
    string = self.value
    string.gsub(/[^\d]/,"").gsub(/^(\d{4}).*/,'\1')+string.gsub(/[^\d]/,"").gsub(/^\d{4}/,"").gsub(/\d/,"#")
  end

  private

  def mobile_uniqueness
    return unless category.to_s.camelcase == 'Mobile'

    r = Contact.where( 'contact_attributes._type' => 'Telephone',
                       'contact_attributes.category' => 'Mobile',
                       'contact_attributes.value' => value )

    errors[:value] << "mobile is not unique" if r.count > 0
  end

  def camelize_category
    self.category = self.category.to_s.camelcase
  end

end