require File.dirname(__FILE__) + '/../spec_helper'

describe ContactAttribute do
  it { should have_field(:public).of_type(Boolean) }
  it { should have_field(:value).of_type(String) }
  it { should validate_presence_of(:value) }

  it { should be_referenced_in :account }


  describe "#for_account" do
    before do
      @empty_account = Account.make
      @ok_account = Account.make
      @contact = Contact.make(:owner => @ok_account)
      @contact.contact_attributes << ContactAttribute.make(:account => @ok_account)
      @contact.save
    end

    it "should return the attributes corresponding to the account" do
      assert @contact.contact_attributes.for_account(@ok_account).any?
    end

    it "should return public attributes" do
      @contact.contact_attributes.first.public = true
      @contact.save
      assert @contact.contact_attributes.for_account(@empty_account).any?
    end

    it "should filter the attributes corresponding other accounts" do
      assert_empty @contact.contact_attributes.for_account @empty_account
    end
  end

  describe "When created" do
    before do
      @account = Account.make
      @contact = Contact.make(:owner => @account)
      @contact.contact_attributes << ContactAttribute.make(:account => nil)
      @contact.save
    end

    it "should be owned by contact owner if not specified" do
      @contact.contact_attributes.first.account.should == @account
    end
  end
end