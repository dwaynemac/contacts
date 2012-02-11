require 'spec_helper'

describe LocalUniqueAttribute do
  it { should have_field(:value) }
  it { should be_embedded_in(:contact) }
  it { should belong_to_related(:account) }

  it "should validate presence of :account" do
    lua = LocalUniqueAttribute.make_unsaved(account: nil)
    lua.contact.should_not be_nil
    lua.account.should be_nil
    lua.should_not be_valid
  end

  it "should validate uniqueness of :account_id scoped to :contact_id" do
    lua = LocalUniqueAttribute.make
    invalid = LocalUniqueAttribute.make_unsaved(contact: lua.contact, account: lua.account)
    invalid.should be_invalid
  end

  describe "account_name" do
    before do
      @account = Account.make
      @ls = LocalUniqueAttribute.make(account: @account)
    end
    it "should return account name" do
      @ls.account_name.should == @account.name
    end
    it "should set account by name" do
      new_account = Account.make
      @ls.account_name=(new_account.name)
      @ls.save
      @ls.account.should == new_account
    end
  end

  describe "as_json" do
    let(:ls){LocalUniqueAttribute.make}
    it "should include :account_name" do
      ls.account.should_not be_nil
      ls.to_json.should match /account_name/
    end
    it "should exclude :account_id" do
      ls.to_json.should_not match /account_id/
    end
  end
end
