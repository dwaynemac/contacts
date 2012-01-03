require 'spec_helper'

describe SmartList do
  it { should belong_to_related :account }

  describe "#contacts" do
    before do
      @account = Account.make
      @dw = Contact.make(owner: @account, first_name: "Dwayne")
      @not_dw = Contact.make(owner: @account, first_name: "Luis")
      @student = Contact.make(owner: @account, local_statuses: [{account: @account, status: 'student'}])
      other_acc = Account.make
      @other_account_student = Contact.make(owner: other_acc, local_statuses: [{account:other_acc,status:'student'}])
      @not_student = Contact.make(owner: @account, local_statuses: [{account: @account, status: 'prospect'}])
    end

    it "should return contacts that match this smartlist conditions" do
      sl = @account.smart_lists.new(name: 'dwaynes', query: Contact.where(first_name: 'Dwayne').scoped)
      sl.contacts.should include @dw
      sl.contacts.should_not include @not_dw
    end

    describe "local_status condition should consider account." do
      let(:sl){SmartList.new( account: @account,
                              query: Contact.where('local_statuses.account_id' => @account.id,
                                                   :status => 'student').scoped
      )}
      it "should include self contacts that match status" do
        sl.contacts.should include @student
      end
      it "should ignore self contacts that dont match" do
        sl.contacts.should_not include @not_student
      end
      it "should ignore contacts that match status in other account" do
        sl.contacts.should_not include @other_account_student
      end
    end
  end
end
