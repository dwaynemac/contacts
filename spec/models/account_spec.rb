require File.dirname(__FILE__) + '/../spec_helper'

describe Account do

  it { should validate_presence_of :name }

  it { should have_many_related :lists }

  it "should validate existing PadmaAccount" do
      # spec_helper mocks PadmaAccount.find
      acc = Account.make_unsaved
      acc.should be_valid
  end

  it "not validate if it inexsistent PadmaAccount " do
      # mock ws interaction
      padma_account = PadmaAccount.new(:name => "mockedAccount")
      PadmaAccount.stub(:find).and_return(nil)

      acc = Account.make_unsaved
      acc.should_not be_valid
  end

  it { should have_many_related :owned_contacts }
  it "should NOT store linked contacts id" do
    expect(subject).not_to have_and_belong_to_many :contacts
  end
  describe "#contacts" do
    let(:account){ Account.make }
    let!(:linked_contact){ Contact.make accounts: [account] }
    let!(:owned_contact){ Contact.make owner: account }
    let!(:owned_and_linked_contact){ Contact.make owner: account, accounts: [account] }
    it "returns linked contacts" do
      expect(account.contacts).to include linked_contact
    end
    it "returns a Mongoid::Criteria" do
      expect(account.contacts).to be_a Mongoid::Criteria
    end
    it "returns owned contacts" do
      expect(account.contacts).to include owned_contact
    end
    it "wont duplicate" do
      expect(account.contacts.count).to eq 3
    end
  end

  describe "(linking)" do
    let(:account){Account.make}
    let(:contact){Contact.make(owner: account)}
    before do
      account.link(contact)
    end

    describe "#link" do
      let(:new_contact){Contact.make(owner: Account.make)}
      it "adds this account to contact's linked accounts" do
        account.link(new_contact)
        new_contact.reload
        expect(new_contact.accounts).to include account
      end
      it "adds contact to Account#contacts" do
        account.link(new_contact)
        expect(account.contacts).to include new_contact
      end
    end

    describe "#unlink" do
      it "removes accounts from contact's linked accounts" do
        expect(contact.accounts).to include account
        account.unlink(contact)
        contact.reload
        expect(contact.accounts).not_to include account
      end
      it "removes contact from account#contacts" do
        expect(account.contacts).to include contact
        account.unlink(contact)
        expect(account.contacts).not_to include contact
      end
      it "removes contact from all account's lists" do
        account.unlink(contact)
        account.lists.each{|l|l.contacts.should_not include(contact)}
      end
      it "removed all link between contact and account" do
        account.unlink(contact)
        account.contacts.should_not include(contact)
      end
    end

    describe "#linked_to?" do
      it "returns true if there is relationship with the contact" do
        expect(account).to be_linked_to contact
        account.unlink contact
        expect(account).not_to be_linked_to contact
      end
    end
  end
end
