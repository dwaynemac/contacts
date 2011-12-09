require 'faker'
require 'machinist'
require 'machinist/mongoid'

Contact.blueprint do
  first_name { Faker::Name.first_name }
  last_name { Faker::Name.last_name }
  owner { Account.make }
end

LocalStatus.blueprint do
  contact { Contact.make }
  account { Account.make }
  status { :prospect }
end

ContactAttribute.blueprint do
  account { Account.make }
  value "any-value"
end

Telephone.blueprint do
  value "12314234"
end

Email.blueprint do
  value { Faker::Internet.email }
end

Address.blueprint do
  account { Account.make }
  value "luis maria campos"
end

Account.blueprint do
  name { Faker::Internet.user_name }
end

List.blueprint do
  name { Faker::Internet.user_name }
  account { Account.make }
end
