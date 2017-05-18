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
end
