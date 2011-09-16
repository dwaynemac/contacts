class Telephone < ContactAttribute
  field :category
  field :value

  validates :value, :numericality => true
end