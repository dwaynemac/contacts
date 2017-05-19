require 'ar_spec_helper'

describe NewAccount do
  it { should respond_to(:name) }

  it { should validate_presence_of(:name) }

  it { should have_many(:owned_contacts) }

  it { should have_many(:contacts).through(:account_contacts) }

  it "should validate existing PadmaAccount" do
      # spec_helper mocks PadmaAccount.find
      acc = NewAccount.make_unsaved
      acc.should be_valid
  end

  it "not validate if it inexsistent PadmaAccount " do
      # mock ws interaction
      padma_account = PadmaAccount.new(:name => "mockedAccount")
      PadmaAccount.stub(:find).and_return(nil)

      acc = NewAccount.make_unsaved
      acc.should_not be_valid
  end

  describe "#contacts" do
    let(:account){ NewAccount.make }
    let!(:linked_contact){ NewContact.make accounts: [account] }
    let!(:owned_contact){ NewContact.make owner: account }
    let!(:owned_and_linked_contact){ NewContact.make owner: account, accounts: [account] }
    it "returns linked contacts" do
      expect(account.contacts).to include linked_contact
    end
    it "returns an Array" do
      expect(account.contacts).to be_a Array
    end
    it "returns owned contacts" do
      expect(account.contacts).to include owned_contact
    end
    it "wont duplicate" do
      expect(account.contacts.count).to eq 3
    end
  end

  describe "(linking)" do
    let(:account){NewAccount.make}
    let(:contact){NewContact.make(owner_id: account.id)}
    before do
      account.link(contact)
    end

    describe "#link" do
      let(:new_contact){NewContact.make(owner_id: NewAccount.make)}
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
      before do
        expect(contact.accounts).to include account
        expect(account.contacts).to include contact
        account.unlink(contact)
        account.reload
        contact.reload
      end
      it "wont delete account document" do
        expect(NewAccount.find(account.id)).not_to be_nil
      end
      it "wont delete contact document" do
        expect(NewContact.find(contact.id)).not_to be_nil
      end
      it "removes accounts from contact's linked accounts" do
        expect(account).not_to be_in contact.accounts
      end
      it "removes contact from account#contacts" do
        expect(contact).not_to be_in account.contacts
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
