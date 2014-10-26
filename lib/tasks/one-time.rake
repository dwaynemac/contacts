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
  Contact.where(link_upgraded: nil).each do |contact|
    cur_account_ids = contact.account_ids
    contact.account_ids = cur_account_ids + contact.lists.map do|l|
      l.account_id
    end
    contact.save(validate: false)
  end
end
