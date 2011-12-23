require File.dirname(__FILE__) + '/../spec_helper'

describe Account do

    it { should validate_presence_of :name }

    it { should have_many_related :owned_contacts }

    it { should have_many_related :lists }

    #it do
    #  Account.make
    #  should validate_uniqueness_of :name
    #end

    it "should validate existing PadmaAccount" do
        # spec_helper mocks PadmaAccount.find
        acc = Account.make_unsaved
        acc.should be_valid
    end

    it "not validate if it inexsistent PadmaAccount " do
        # mock ws interaction
        padma_account = PadmaAccount.new(:name => "mockedAccount")
        PadmaAccount.stub!(:find).and_return(nil)

        acc = Account.make_unsaved
        acc.should_not be_valid
    end

    it "should create base list on creation" do
      acc = Account.make_unsaved
      acc.save
      acc.reload.lists.should have_at_least(1).list
    end

  specify "#base_list returns account's base list" do
    a = Account.make
    a.base_list.should be_a(List)
    a.base_list.name.should == a.name
  end
end
