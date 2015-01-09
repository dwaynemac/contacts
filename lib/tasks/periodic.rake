namespace :periodic do

  desc "removes any tags without associated contacts"
  task :remove_empty_tags => :environment do
    Tag.remove_all_empty
  end

  desc 'notify birthdays'
  task :notify_today_birthdays => :environment do
    bd = BirthdayNotificator.new
    bd.deliver_notifications
  end

  desc 'synchronize with mailchimp'
  task :synchronize_with_mailchimp => :environment do
    MailchimpSynchronizer.all.each do |ms|
      Rails.logger.info "MAILCHIMP - synchronizing #{ms.account.name}"
      ms.subscribe_contacts # this will queue to background
    end
  end
end
