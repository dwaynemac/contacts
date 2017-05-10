require 'ar_spec_helper'

describe NewAccount, ar: true do
  it { should respond_to(:name) }

  it { should validate_presence_of(:name) }

  it { should have_many(:owned_contacts) }

  it { should have_many(:contacts).through(:account_contacts) }
end
