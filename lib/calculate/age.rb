class Calculate::Age 
  
  # @param options[Hash]
  # @option options [Array] contacts (nil)
  # @option options [Date] ref_date (today)
  def initialize(options={})
    @ref_date = options[:ref_date] || Date.today
    @contacts = options[:contacts]
  end

  # @return [Array] collection of contacts over which average age will be calculated
  def contacts
    @contacts
  end

  # @return [Integer] returns age of contact at self.ref_date
  def age_for(contact)
    age = if contact.birthday && !contact.birthday.year.blank?
      bday = contact.birthday
      @ref_date.year - bday.year.to_i - ((@ref_date.month > bday.month.to_i || (@ref_date.month == bday.month.to_i && @ref_date.day >= bday.day.to_i)) ? 0 : 1)
    elsif contact.estimated_age_on
      bday = contact.estimated_age_on - contact.estimated_age.years
      @ref_date.year - bday.year.to_i - ((@ref_date.month > bday.month.to_i || (@ref_date.month == bday.month.to_i && @ref_date.day >= bday.day.to_i)) ? 0 : 1)
    else
      contact.estimated_age
    end
    (age && age < 0)? nil : age
  end

  # maps ages of contacts collection
  # ignores nil's
  # @return [Array]
  def ages
    @ages ||= contacts.map{|c| age_for(c) }.compact
  end

  # @return [Float]
  def average
    @average ||= ages.inject(:+).to_f / ages.size
  end
end
