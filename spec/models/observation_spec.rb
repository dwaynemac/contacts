require 'spec_helper'

describe Observation do
  let(:contact){ Contact.make } 
  let(:account){ Account.make }
  describe "When saving a contact" do
    it "observation value should not be blank" do
      contact.local_unique_attributes << Observation.new(value: nil)
      contact.valid?.should be_false
    end
    it "should save if value is not blank" do
      contact.local_unique_attributes << Observation.new(value: "an observation", account_id: account.id)
      contact.save!
      contact.observations.count.should == 1
      contact.observations.first.value.should == "an observation"
    end
  end
end
