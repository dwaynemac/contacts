require File.dirname(__FILE__) + '/../spec_helper'

describe List do
  it { should belong_to_related :account }

  it { should reference_and_be_referenced_in_many :contacts }

  it { should have_field :name }

  it { should validate_presence_of :name }

  it { should validate_presence_of :account }

  it "should allow access to contacts" do
    l = List.make
    a = l.account
    c = Contact.make(:lists => [l])
    l.reload
    l.contacts.should == [c]
    a.lists.first.contacts.should == [c]
  end
end