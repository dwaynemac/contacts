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
    begin
      Appsignal::Transaction.create(SecureRandom.uuid, ENV.to_hash)
      ActiveSupport::Notifications.instrument(
        'perform_job.rake_synchronize_with_mailchimp',
        class: 'MailchimpSynchronizer',
        method: 'synchronize_all',
        queue_time: 0
      ) do
        MailchimpSynchronizer.synchronize_all
      end
    end
  end
end
