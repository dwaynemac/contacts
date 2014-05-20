class LastSeenAt < LocalUniqueAttribute

  validate :valid_date

  private

  def valid_date
    unless self.value <= Time.now.utc
      errors.add(:value)
      false
    end
  end

end
