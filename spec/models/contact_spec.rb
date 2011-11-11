require File.dirname(__FILE__) + '/../spec_helper'

describe Contact do
  it { should embed_many :contact_attributes }

  it { should belong_to_related :owner }

  it { should reference_and_be_referenced_in_many :lists }

  it { should have_fields :first_name, :last_name }

  it { should validate_presence_of :first_name }

  describe "when scoped to a list" do
    before do
      @account = Account.make
      @contact = @account.lists.first.contacts.create(:first_name => "Marge")
    end

    it "should set the owner" do
      @contact.owner.should == @account
    end

    it "should update the lists contacts" do
      @account.lists.first.contacts.should include(@contact)
    end

    describe "and after adding the contact to a new list" do
      before do
        @account_b = Account.make(:lists => [List.make])
        @contact.lists << @account_b.lists.first
      end

      specify { @contact.lists.count.should == 2 }

      it "should not update the owner" do
        @contact.owner.should == @account
      end
    end
  end

  describe "#create with nested attribute params" do
    before do
      @account = Account.make
      @contact = Contact.create(Contact.plan(:owner => @account, :contact_attributes => [ContactAttribute.plan(:account => nil)]))
    end

    it "should set the owner on new attributes" do
      @contact.contact_attributes.first.account.should == @account
    end
  end

  describe "#save" do
    before do
      @account = Account.make
      @contact = Contact.create(Contact.plan(:owner => @account, :contact_attributes => [ContactAttribute.plan()]))
      @contact.lists = []
      @contact.save
    end

    it "should set the owners main list" do
      @contact.lists.first.should == @account.lists.first
    end
  end

  describe "#save with nested attribute params" do
      before do
        @account = Account.make
        @contact = Contact.create(Contact.plan(:owner => @account))
        @contact.update_attributes(:contact_attributes => [ContactAttribute.plan(:account => nil)])
      end

      it "should set the owner on new attributes" do
        @contact.contact_attributes.first.account.should == @account
      end
  end

  describe "mongoid_search" do
    before do
      account = Account.make

      @first_name = Contact.make(first_name: "dwayne")
      @first_name.contact_attributes << Telephone.new(account_id: account._id, value: "1234")
      @first_name.save

      @email = Contact.make(last_name: "mac")
      @email.contact_attributes << Email.new(account_id: account._id, value: "dwaynemac@gmail.com")
      @email.save

      @last_name = Contact.make(first_name: "asdf", last_name: "dwayne")
    end
    it "should find by email" do
      Contact.csearch("dwaynemac@gmail.com").should include(@email)
    end
  end

end
