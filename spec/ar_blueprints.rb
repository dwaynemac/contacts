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

