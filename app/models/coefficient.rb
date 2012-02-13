class Coefficient < LocalUniqueAttribute

  VALID_VALUES = %w(unknown fp pmenos perfil pmas) # Order is important and used.
  validates_inclusion_of :value, in: VALID_VALUES, allow_blank: true

  def as_json(options)
    super({except: [:created_at, :updated_at]}.merge(options||{}))
  end

  # @param [ Coefficient ] other The coefficient to compare with.
  #
  # @return [ Integer ] -1, 0, 1.
  def <=>(other)
    VALID_VALUES.index(self.value) <=> VALID_VALUES.index(other.value)
  end
end
