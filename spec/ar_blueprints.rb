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
  account { NewAccount.make }
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