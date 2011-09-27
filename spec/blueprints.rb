require 'faker'
require 'machinist'
require 'machinist/mongoid'

Contact.blueprint do
  first_name { Faker::Name.first_name }
  last_name { Faker::Name.last_name }
  owner { Account.make }
end

ContactAttribute.blueprint do
  account { Account.make }
end

Account.blueprint do
  name { Faker::Internet.user_name }
end

List.blueprint do
  name { Faker::Internet.user_name }
  account { Account.make }
end
