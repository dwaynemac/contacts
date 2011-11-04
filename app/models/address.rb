class Address < ContactAttribute
  field :category
  field :address
  field :postal_code
  field :city
  field :state
  field :country

  before_save :set_value

  private
  def set_value
    self.value = "#{address}, #{city}, #{state}, #{country} (#{postal_code})"
  end
end