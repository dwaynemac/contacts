class Coefficient < LocalUniqueAttribute
  field :value, type: Integer

  UNKNOWN = 0
  FP      = 2
  PMENOS  = 3
  PERFIL  = 4
  PMAS    = 5

  VALID_VALUES = [UNKNOWN, FP, PMENOS, PERFIL, PMAS]

  validates_inclusion_of :value, in: VALID_VALUES
end
