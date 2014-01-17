class Observation < LocalUniqueAttribute

  validates_presence_of :value

  def as_json(options)
    super({except: [:created_at, :updated_at]}.merge(options||{}))
  end
end
