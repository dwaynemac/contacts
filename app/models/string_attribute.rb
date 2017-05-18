class StringAttribute < NewContactAttribute

  def value
    self[:string_value]
  end

  def value=str
    self[:string_value]=str
  end

end
