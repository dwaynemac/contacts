require File.dirname(__FILE__) + '/../spec_helper'

describe Email do
  it { should validate_presence_of :value }
end

describe Email do
  it "should be unique" do
    c = Contact.make(:first_name => "Bart", :last_name => "Simpson")
    c.contact_attributes << Email.new(:category => :home, :value => "bart@thesimpsons.com")
    c.save!
    c2 = Contact.new(:first_name => "El", :last_name => "Barto")
    c2.contact_attributes << Email.new(:category => :home, :value => "bart@thesimpsons.com")
    assert !c2.valid?
  end

  it "should be normalized" do
    c = Contact.make(:first_name => "Shinji", :last_name => "Ikari")
    c.contact_attributes << Email.new(:value => "EVA_PILOT_01@GMAIL.COM")
    c.save!
    c.email.should == "eva_pilot_01@gmail.com"
  end

end
