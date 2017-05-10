# encoding: UTF-8
require 'ar_spec_helper'

describe NewContact, ar: true do

  it { should have_many(:accounts).through(:account_contacts) }
  
  it { should belong_to :owner }

  it { should respond_to(:first_name, :last_name) }
  
  it { should validate_presence_of :first_name }
  
end
