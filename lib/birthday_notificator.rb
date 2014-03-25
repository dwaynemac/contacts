class BirthdayNotificator

  def self.initialize

  end

  def deliver_notifications
    all_birthdays.each do |contact|
      #TODO manage different responses: 201, 500, etc...
      Messaging::Client.post_message('birthday', json_for(contact))
    end
  end

  def all_birthdays
    Contact.api_where(date_attribute: {category: 'birthday', month: Date.today.month, day: Date.today.day})
  end

  def json_for(contact)
    json = {}
    contact.local_statuses.each do |ls|
      json.merge!({"local_status_for_#{ls.account_name}" => ls.value})
    end
    contact.coefficients.each do |lc|
      json.merge!({"local_coefficient_for_#{lc.account_name}" => lc.value })
    end
    json.merge!({
                    status: contact.status,
                    gender: contact.gender,
                    birthday_at: Date.today,
                    linked_accounts_names: contact.linked_accounts.map(&:name)
    })
    unless contact.emails.empty?
      json.merge!({recipient_email: contact.email})
    end
    json
  end
end
