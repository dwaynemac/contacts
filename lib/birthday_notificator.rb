class BirthdayNotificator

  def self.initialize

  end

  def deliver_notifications
    all_birthdays.each do |contact|
      log("broadcasting birthday of #{contact.id}")
      unless Messaging::Client.post_message('birthday', json_for(contact))
        warn("bday broadcast for #{contact.id} failed.")
      end
    end
  end

  def all_birthdays
    Contact.api_where(date_attribute: {category: 'birthday',
                                       month: Date.today.month,
                                       day: Date.today.day})
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
    
    json.merge!({contact_id: contact.id.to_s})

    unless contact.emails.empty?
      gpe = contact.global_primary_attribute('Email')
      json.merge!({recipient_email: gpe.value}) unless gpe.nil?
    end

    json
  end

  private

  def log(msg)
    logger.info("[birthday_notificator] #{msg}")
  end

  def warn(msg)
    logger.warn("[birthday_notificator] #{msg}")
  end

  ##
  # Encapsulated logger here in case we wish to change it
  # for BirthdayNotificator
  def logger
    Rails.logger
  end
end
