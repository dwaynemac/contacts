require File.dirname(__FILE__) + '/../spec_helper'

describe Email do
  before do
    Contact.destroy_all
  end

  it { should validate_presence_of :value }

  it "should NOT be unique" do
    c = Contact.make(:first_name => "Bart", :last_name => "Simpson")
    c.contact_attributes << Email.new(:category => :personal, :value => "bart@thesimpsons.com")
    c.save!
    c2 = Contact.new(:first_name => "El", :last_name => "Barto")
    c2.contact_attributes << Email.new(:category => :personal, :value => "bart@thesimpsons.com", allow_duplicate: true)
    c2.check_duplicates = false
    c2.should be_valid
  end

  it "should be normalized" do
    c = Contact.make(:first_name => "Shinji", :last_name => "Ikari")
    c.contact_attributes << Email.new(:value => "EVA_PILOT_01@GMAIL.COM")
    c.save!
    c.global_primary_attribute('Email').value.should == "eva_pilot_01@gmail.com"
  end
end
