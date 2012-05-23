namespace :update do
  desc <<-DESC
  Copy all primary attributes to contact
  DESC
  task :replicate_primary_ca => :environment do
    Contact.find(:all).each { |co|
      co.contact_attributes.where(:primary => true).each { |ca|
        puts ca._type.to_sym
        puts ca.value
        ca.contact[ca._type.to_sym] = ca.value
        ca.contact.save
      }
    }
  end
end

