require File.dirname(__FILE__) + '/../spec_helper'

describe Telephone do
  before do
    @bart = Contact.make(:first_name => "Bart", :last_name => "Simpson")
    @bart.contact_attributes << Telephone.new(:category => :Mobile, :value => "1540995071")
    @bart.save
  end

  it { should validate_presence_of :value }

  ["15 4099 5071", "4568-8754"].each do |v|
    it { should_not allow_value(v).for(:value) }
  end

  ["47746357", "1234321", "12341234"].each do |v|
    it { should allow_value(v).for(:value) }
  end

  ["-165", "654."].each do |v|
    it { should_not allow_value(v).for(:value)}
  end

  describe "category" do
    it "should always be saved camelcased" do
      @bart.contact_attributes << Telephone.make(:category => :no_camel)
      @bart.reload
      @bart.telephones.map(&:category).should include("NoCamel")
    end
  end

  specify "#masked_value" do
    @contact = Contact.make
    @contact.contact_attributes << Telephone.new(category: :Mobile, value: "15 4099 5071")
    @contact.contact_attributes.last.masked_value.should == "1540######"
  end

  describe "of 'Mobile' category should be unique" do
    specify "so two contacts can't have same mobile" do
      c = Contact.new(:first_name => "El", :last_name => "Barto")
      c.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071")
      c.should_not be_valid
    end
    specify "same contact cant have duplicated mobile" do
      @bart.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071")
      @bart.should_not be_valid
    end
    specify "so different mobile phones should be fine" do
      c = Contact.new(:first_name => "El", :last_name => "Barto")
      c.contact_attributes << Telephone.new(:category => :mobile, :value => "1540993333")
      c.should be_valid
    end
  end

  specify "categories other than 'mobile' shouldn't be unique'" do
    c = Contact.new(:first_name => "Bartman")
    c.contact_attributes << Telephone.new(:category => :home, :value => "1540995071")
    c.should be_valid
  end

end