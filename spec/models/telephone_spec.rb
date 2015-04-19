require File.dirname(__FILE__) + '/../spec_helper'

describe Telephone do
  before do
    @bart = Contact.make(:first_name => "Bart", :last_name => "Simpson")
    @bart.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071")
    @bart.save
  end

  it { should validate_presence_of :value }

  ["15 4099 5071", "4568-8754", "(11) 99999-9999"].each do |v|
    it { should allow_value(v).for(:value) }
  end

  ["47746357", "12343210", "12341234"].each do |v|
    it { should allow_value(v).for(:value) }
  end

  ["-165", "654.", "123412341234123412341234123412341234123123123412341234123412341234123412341234123123"].each do |v|
    it { should_not allow_value(v).for(:value)}
  end

  #describe "category" do
  #  it "should always be saved camelcased" do
  #    @bart.contact_attributes << Telephone.make(:category => :no_camel)
  #    @bart.reload
  #    @bart.telephones.map(&:category).should include("NoCamel")
  #  end
  #end

  specify "#masked_value" do
    @contact = Contact.make
    @contact.contact_attributes << Telephone.new(category: :mobile, value: "1540995071")
    @contact.contact_attributes.last.masked_value.should == "######5071"
  end

  specify "allow duplicates" do
    c = Contact.new(:first_name => "Bartman")
    c.contact_attributes << Telephone.new(:category => :home, :value => "1540995071")
    c.should be_valid
  end

end
