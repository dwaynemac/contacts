require File.dirname(__FILE__) + '/../spec_helper'

describe List do

  subject { List.make }

  it { should belong_to_related :account }

  it { should reference_and_be_referenced_in_many :contacts }

  it { should have_field :name }

  it { should validate_presence_of :name }
  it "should validate uniqueness of :name within an :account" do
    should validate_uniqueness_of(:name).scoped_to(:account_id).with_message("name is already taken")
  end

  it { should validate_presence_of :account }

  it "should allow access to contacts" do
    l = List.make
    a = l.account
    c = Contact.create(:first_name => "Barney", :lists => [l])
    l.reload
    l.contacts.should == [c]
    a.lists.first.contacts.should == [c]
  end
end