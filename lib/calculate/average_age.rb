class Calculate::AverageAge 
  
  def initialize(options={})
    @account_name = options[:account_name]
    @ref_date = options[:ref_date] || Date.today
  end

  def contacts
    @contacts ||= Contact.api_where(account_name: @account_name, status: 'student', local_status: 'student')
   # PadmaContact.search(:select => :all, :where => {:status => :student, :local_status => :student}, :account_name => 'martinez')
  end

  def get_age_for(contact)
    if contact.birthday && !contact.birthday.year.blank?
      bday = contact.birthday
      @ref_date.year - bday.year.to_i - ((@ref_date.month > bday.month.to_i || (@ref_date.month == bday.month.to_i && @ref_date.day >= bday.day.to_i)) ? 0 : 1)
    elsif contact.estimated_age_on
      bday = contact.estimated_age_on - contact.estimated_age.years
      @ref_date.year - bday.year.to_i - ((@ref_date.month > bday.month.to_i || (@ref_date.month == bday.month.to_i && @ref_date.day >= bday.day.to_i)) ? 0 : 1)
    else
      contact.estimated_age
    end
  end

  def ages
    contacts.map do |contact|
      if contact.age
        contact.age
      end
    end
  end

end
