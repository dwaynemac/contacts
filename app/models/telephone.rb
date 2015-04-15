class Telephone < ContactAttribute
  TEL_REGEX = /^[\(|\d][\d| |\)\-|\.]{6,16}.*\d$/
  field :category

  #before_validation :camelize_category
  before_validation :strip_whitespace

  # validates_numericality_of :value, only_integer: true, greater_than: 0
  # validates_format_of :value, with: /^\d[\d| |\-]{4,16}.*\d$/
  validates_format_of :value, :with => TEL_REGEX, :message=>"not a valid phone. Allowed characters:' ', '.' y '-'. Minumum 8 digits.", :allow_blank=>true
  validates_length_of :value, :maximum => 45, allow_nil: true

  def masked_value
    string = self.value
    string.gsub(/[^\d]/,"").gsub(/^\d{4}/,"").gsub(/\d/,"#")+string.gsub(/[^\d]/,"").gsub(/^.*(\d{4})/,'\1')
  end

  scope :mobiles, where( category: 'mobile' )

  private

  def camelize_category
    self.category = self.category.to_s.camelcase
  end

  def strip_whitespace
    self.value = self.value.strip
  end

end
