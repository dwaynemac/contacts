require 'spec_helper'

describe LocalTeacher do
  it { should be_embedded_in(:contact) }
  it { should belong_to_related(:account) }
  it { should validate_presence_of(:account) }

  specify "each account should have only one local teacher per contact" do
    c = Contact.make
    a = Account.make
    c.local_unique_attributes <<  LocalTeacher.make(account: a)
    c.local_unique_attributes <<  LocalTeacher.make(account: a)
    c.should_not be_valid
  end

  specify "an account can have local teacher on each contact" do
    a = Account.make
    c = Contact.make(local_unique_attributes: [LocalTeacher.make(account: a)])
    oc = Contact.make(local_unique_attributes: [LocalTeacher.make(account: a)])
    c.should be_valid
    oc.should be_valid
  end

  specify "many accounts may have local teachers on same contact" do
    c = Contact.make
    5.times { c.local_unique_attributes <<  LocalTeacher.make }
    c.should be_valid
  end

  let(:account){Account.make(name: 'acc_name')}
  let(:contact){Contact.make}
  it "creates a history_entry after change" do
    account # create account
    expect{contact.local_teacher_for_acc_name = 'fulano'}.to change{HistoryEntry.count}.by(1)
  end

  it "broadcasts activity after change" do
    account # create account
    ActivityStream::Activity.any_instance.should_receive(:create)
    contact.local_teacher_for_acc_name = 'fulano'
  end

  describe "account_name" do
    before do
      @contact = Contact.make
      @account = Account.make
      @contact.local_unique_attributes <<  LocalTeacher.make(account: @account)
      @contact.save
      @ls = @contact.local_teachers.first
    end
    it "should return account name" do
      @ls.account_name.should == @account.name
    end
    it "should set account by name" do
      new_account = Account.make
      @ls.account_name=(new_account.name)
      @contact.save
      @contact.reload
      @contact.local_teachers.first.account.should == new_account
    end
  end
  describe "as_json" do
    before do
      @contact = Contact.make
      @account = Account.make
      @contact.local_unique_attributes <<  LocalTeacher.make(account: @account)
      @contact.save
      @ls = @contact.local_teachers.first
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
