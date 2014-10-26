task :josue_to_anabella => :environment do
  since = Date.civil(2012,2,1)
  old_user = 'josue.barba'
  new_user = 'anabella.tedesco'
  on_account_name = 'palermo'

  Contact.api_where(
          local_status_for_palermo: 'student',
          local_teacher_for_palermo: old_user
         ).each do |contact|
    contact.local_teacher_for_palermo= new_user
    contact.save
  end
end

task :link_contacts_and_accounts => :environment do
  Contact.all.each do |contact|
    puts "linking contact #{contact.id}"
    puts "pre: #{contact.account_ids}"
    contact.account_ids = contact.lists.map do|l|
      puts "with #{l.account_id}"
      l.account_id
    end
    puts "post: #{contact.account_ids}"
    contact.save(validate: false)
  end
end
