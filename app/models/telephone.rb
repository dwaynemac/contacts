class Telephone < ContactAttribute
  field :category

  validates :value, :numericality => true
end