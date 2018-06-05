namespace :periodic do
  
  task :email_admin_for_debug => :environment do
    ContactsMailer.message_admin("cron running ok").deliver
  end
  
  task :fix_global_status => :environment do
    Contact.where(local_unique_attributes: { '$elemMatch' => { _type: 'LocalStatus', value: 'student' }})
           .where(status: { '$in' => [nil,:prospect,:former_student] })
           .each{|c| c.update_status! }
    
    Contact.where(local_unique_attributes: { '$elemMatch' => { _type: 'LocalStatus', value: { '$nin' => 'student'.to_a} }})
           .where(status: :student)
           .each{|c| c.update_status! }
  end
  
  task :notify_pending_merges => :environment do
    Merge.where(state: 'pending_confirmation').each do |merge|
      ContactsMailer.notify_merge_needing_confirmation(merge).deliver
    end
  end

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
