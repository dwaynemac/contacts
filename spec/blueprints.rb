require 'faker'
require 'machinist'
require 'machinist/mongoid'

Contact.blueprint do
  first_name { Faker::Name.first_name }
  last_name { Faker::Name.last_name }
  owner { Account.make }
end

Merge.blueprint do
  first_contact { Contact.make(first_name: 'first_name', last_name: 'last name') }
  second_contact { Contact.make(first_name: 'first_name2', last_name: 'last name') }
end

LocalStatus.blueprint do
  contact { Contact.make }
  account { Account.make }
  value { :prospect }
end

LocalTeacher.blueprint do
  contact { Contact.make }
  account { Account.make }
end

LocalUniqueAttribute.blueprint do
  contact { Contact.make }
  account { Account.make }
  value "a-value"
end

ContactAttribute.blueprint do
  account { Account.make }
  value "any-value"
end

Telephone.blueprint do
  value  "8765987676"
  category { "Home" }
end

Email.blueprint do
  value { Faker::Internet.email }
  category { "Homer" }
end

Address.blueprint do
  account { Account.make }
  value "luis maria campos"
end

Identification.blueprint do
  account { Account.make }
  value '30366843'
  category "DNI"
end

Account.blueprint do
  name { Faker::Internet.user_name }
end

List.blueprint do
  name { Faker::Internet.user_name }
  account { Account.make }
end
