class Email < ContactAttribute
  field :category
  field :value

  validates :value, :presence => true, :email => true
end