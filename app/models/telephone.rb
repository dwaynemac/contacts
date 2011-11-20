class Telephone < ContactAttribute
  field :category

  validates :value, :numericality => true

  def masked_value
    string = self.value
    string.gsub(/[^\d]/,"").gsub(/^(\d{4}).*/,'\1')+string.gsub(/[^\d]/,"").gsub(/^\d{4}/,"").gsub(/\d/,"#")
  end

end