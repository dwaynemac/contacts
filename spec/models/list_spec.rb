require File.dirname(__FILE__) + '/../spec_helper'

describe List do

  subject { List.make }

  it { should belong_to_related :account }

  it { should have_and_belong_to_many :contacts }

  it { should have_field :name }

  it { should validate_presence_of :name }
  it "should validate uniqueness of :name within an :account" do
    a = Account.make
    b = Account.make
    List.make(account: a, name: "list_1")
    invalid = List.make_unsaved(account: a, name: "list_1")
    valid_a = List.make_unsaved(account: a, name: "new_list_name")
    valid_b = List.make_unsaved(account: b, name: "list_1")

    invalid.should_not be_valid
    valid_a.should be_valid
    valid_b.should be_valid

    # should validate_uniqueness_of(:name).scoped_to(:account_id) NOT WORKING due to some i18n bug
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
