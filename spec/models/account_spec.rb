require File.dirname(__FILE__) + '/../spec_helper'

describe Account do

  it { should validate_presence_of :name }

  it { should have_many_related :owned_contacts }

  it { should have_many_related :lists }
  it { should have_many_related :smart_lists }

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

  describe "#base_list" do
    it "returns account's base list" do
      a = Account.make
      a.base_list.should be_a(List)
      a.base_list.name.should == a.name
    end
    it "created base_list if it doesn't exist" do
      a = Account.make
      List.where(name: a.name).destroy
      a.reload
      a.base_list.should be_a List
      a.base_list.name.should == a.name
    end
  end

  describe "#contacts" do
    let(:account){ Account.make }
    before do
      list_a = List.make(account: account)
      list_b = List.make(account: account)
      contact = Contact.make
      account.base_list.contacts << contact
      3.times{ account.base_list.contacts << Contact.make }
      3.times{ list_a.contacts << Contact.make }
      list_b.contacts << Contact.make
      list_b.contacts << contact
      list_a.save!
      list_b.save!
      account.reload
    end
    it "returns a Mongoid::Criteria" do
      account.contacts.should be_a Mongoid::Criteria
    end
    it "returns contacts from all account's lists" do
      account.contacts.count.should == 8
    end
    it "doesnt repeat contacts" do
      account.contacts.count.should == 8
    end
  end

  describe "#link_contact" do
    let(:account){Account.make}
    it "adds contact to account's base list" do
      contact = Contact.make
      account.link_contact(contact)
      account.base_list.contacts.should include(contact)
    end
  end

  describe "#unlink_contact" do
    let(:account){Account.make}
    let(:contact){Contact.make}
    before do
      list = List.make(account: account)
      account.base_list.contacts << contact
      list.contacts << contact
    end
    it "removes contact from all account's lists" do
      account.unlink_contact(contact)
      account.lists.each{|l|l.contacts.should_not include(contact)}
    end
  end

end
