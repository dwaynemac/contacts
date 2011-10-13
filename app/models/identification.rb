class Identification < ContactAttribute
  field :name
  field :value

  validates :value, :presence => true # , :uniqueness => {:scope => :name}
  validates :name, :presence => true #, :uniqueness => {:scope => :contact}
end