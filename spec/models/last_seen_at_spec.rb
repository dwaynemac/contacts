require 'spec_helper'

describe LastSeenAt do
  let(:contact){ Contact.make } 
  let(:account){ Account.make }
  describe "When saving a contact" do
    it "last_seen_at value should not be in the future" do
      contact.local_unique_attributes << LastSeenAt.new(value: 1.hour.from_now.utc)
      contact.valid?.should be_false
    end
    it "should save if value is not blank" do
      contact.local_unique_attributes << LastSeenAt.new(value: 1.hour.ago.utc, account_id: account.id)
      contact.save!
      contact.last_seen_ats.count.should == 1
      contact.last_seen_ats.first.value.round.should == 1.hour.ago.utc.round
    end
    it "should skip validation if value is blank" do
      contact.local_unique_attributes << LastSeenAt.new(value: "", account_id: account.id)
      contact.should be_valid
    end
  end
end
