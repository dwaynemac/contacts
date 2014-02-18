namespace :update do
  desc <<-DESC
  Move all "In Formation" custom attributes to in_professional_training field
  DESC
  task :migrate_in_professional_training => :environment do
    Contact.where( contact_attributes: { '$elemMatch' => { _type: 'CustomAttribute', name: "In formation"}}).each do |c|
        c.in_professional_training = true
        c.save
    end
  end
end

