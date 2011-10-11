require File.dirname(__FILE__) + '/../spec_helper'

describe Contact do
  it { should embed_many :contact_attributes }

  it { should belong_to_related :owner }

  it { should reference_and_be_referenced_in_many :lists }

  it { should have_fields :first_name, :last_name }

  it { should validate_presence_of :first_name }

  describe "should set the owner to the list's account when created" do
    before do
      @account = Account.make
      @contact = @account.lists.first.contacts.create(:first_name => "Marge")
    end

    it {
      @contact.owner.should == @account
    }

    describe "but not when added to a new list" do
      before do
        @account_b = Account.make(:lists => [List.make])
        @contact.lists << @account_b.lists.first
      end

      specify { @contact.lists.count.should == 2 }

      it {
        @contact.owner.should == @account
      }
    end
  end

  describe "#create with nested attribute params" do
    before do
      @account = Account.make
      @contact = Contact.create(Contact.plan(:owner => @account, :account_id => @account.id, :contact_attributes => [{:_type => "ContactAttribute"}]))
    end

    it "should set the owner on new attributes" do
      @contact.contact_attributes.first.account.should == @account
    end
  end
end
