class CustomAttribute < ContactAttribute
  field :name
  field :value

  validate :name, :presence => true
  validate :value, :presence => true
end