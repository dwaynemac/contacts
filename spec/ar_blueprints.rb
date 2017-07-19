require 'faker'
require 'machinist'
require 'machinist/active_record'

NewContact.blueprint do
  first_name { Faker::Name.first_name }
  last_name { Faker::Name.last_name }
  owner { NewAccount.first || NewAccount.make }
end

NewAccount.blueprint do
  name { Faker::Internet.user_name }
end

NewContactAttribute.blueprint do
  account { contact.owner || NewAccount.make }
  value "any-value"
end

NewTelephone.blueprint do
  value  "8765987676"
  category { "Home" }
end

NewEmail.blueprint do
  value { Faker::Internet.email }
  category { "Homer" }
end


NewIdentification.blueprint do
  value { Faker::Internet.email }
  category { "Homer" }
end

NewMerge.blueprint do
  first_contact_id { NewContact.make(first_name: 'first_name', last_name: 'last name').id }
  second_contact_id { NewContact.make(first_name: 'first_name2', last_name: 'last name').id }
end

NewAttachment.blueprint do
  name 'atachment-name'
end

NewImport.blueprint do
  account {NewAccount.first || Nccount.make}
end