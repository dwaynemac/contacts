require 'faker'
require 'machinist'
require 'machinist/mongoid'

Contact.blueprint do
  first_name { Faker::Name.first_name }
  last_name { Faker::Name.last_name }
end

ContactAttribute.blueprint do
  account
end

Account.blueprint do
  name { Faker::Internet.user_name }
end