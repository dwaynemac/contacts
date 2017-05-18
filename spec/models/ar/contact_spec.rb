# encoding: UTF-8
require 'ar_spec_helper'

describe NewContact do

  it { should have_many(:accounts).through(:account_contacts) }
  
  it { should belong_to :owner }

  it { should respond_to(:first_name, :last_name, :status) }
  
  it { should validate_presence_of :first_name }

  describe "owner auto assignment" do
    let(:account){ NewAccount.make }
    let(:contact){NewContact.create(NewContact.plan(owner: account))}

    context "if contact has no status" do
      it "should be linked to account" do
        contact.save
        contact.reload
        expect(account).to be_in contact.accounts
      end
    end

    context "if contact is a student" do
      let!(:new_account){ NewAccount.make }
      before do
        expect do
          contact.send("local_status_for_" + new_account.name + "=", :student)
          contact.save
          contact.reload
        end.to change{contact.status}.to :student
      end
      example "account where it is student should own it" do
        expect(contact.owner).to eq new_account
      end
      it "should be linked to the owner" do
        expect(contact.accounts).to include new_account
      end
    end
  end
  
end
