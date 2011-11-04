class CustomAttribute < ContactAttribute
  field :name

  validate :name, :presence => true
end