require 'spec_helper'

describe LocalStatus do
  it { should have_field(:status).of_type(Symbol) }
  it { should be_embedded_in(:contact) }
  it { should belong_to_related(:account) }
  it { should validate_presence_of(:account) }

  %W(student former_student prospect).each do |s|
    it { should allow_value(s.to_sym).for(:status)}
  end

  ["1234","qwsgdf", :asdf].each do |s|
    it { should_not allow_value(s).for(:status)}
  end

  it "should not allow :student in different accounts" do
    c = Contact.make
    c.local_statuses << LocalStatus.make(status: 'student')
    c.local_statuses << LocalStatus.make(status: 'student')
    c.should_not be_valid
  end

  it "should allow :student in one account" do
    c = Contact.make
    c.local_statuses << LocalStatus.make(status: 'student')
    c.local_statuses << LocalStatus.make(status: 'former_student')
    c.should be_valid
  end

  specify "each account should have only one local status" do
    c = Contact.make
    a = Account.make
    c.local_statuses << LocalStatus.make(account: a)
    c.local_statuses << LocalStatus.make(account: a)
    c.should_not be_valid
  end

  specify "an account can have local_status on each contact" do
    a = Account.make
    c = Contact.make(local_statuses: [LocalStatus.make(account: a)])
    oc = Contact.make(local_statuses: [LocalStatus.make(account: a)])
    c.should be_valid
    oc.should be_valid
  end

  specify "many accounts may have local_statuses" do
    c = Contact.make
    5.times { c.local_statuses << LocalStatus.make }
    c.should be_valid
  end

  describe "account_name" do
    before do
      @contact = Contact.make
      @account = Account.make
      @contact.local_statuses << LocalStatus.make(account: @account)
      @contact.save
      @ls = @contact.local_statuses.first
    end
    it "should return account name" do
      @ls.account_name.should == @account.name
    end
    it "should set account by name" do
      new_account = Account.make
      @ls.account_name=(new_account.name)
      @contact.save
      @contact.reload
      @contact.local_statuses.first.account.should == new_account
    end
  end
  describe "as_json" do
    before do
      @contact = Contact.make
      @account = Account.make
      @contact.local_statuses << LocalStatus.make(account: @account)
      @contact.save
      @ls = @contact.local_statuses.first
    end
    let(:ls){@ls}
    it "should include :account_name" do
      ls.to_json.should match /account_name/
    end
    it "should exclude :account_id" do
      ls.to_json.should_not match /account_id/
    end
  end
end
