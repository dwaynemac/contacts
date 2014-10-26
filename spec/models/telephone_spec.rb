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
    @contact.contact_attributes.last.masked_value.should == "1540######"
  end

  describe "of 'mobile' category" do
    specify "ensure contact is valid" do
      @bart.reload
      @bart.save!
    end


    describe "when Contact#check_duplicates is true (default)" do
      specify "two contacts can't have same mobile" do
        c = Contact.new(:first_name => "El", :last_name => "Barto")
        c.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071")
        c.should_not be_valid
      end
      specify "same contact can have duplicated mobile (they may be visible to different accounts)" do
        @bart.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071")
        @bart.should be_valid
      end
      specify "different mobile phones should be fine" do
        c = Contact.new(:first_name => "El", :last_name => "Barto")
        c.contact_attributes << Telephone.new(:category => :mobile, :value => "1540993333")
        c.should be_valid
      end
    end
    describe "when Contact#check_duplicates is false" do
      specify "two contacts can't have same mobile" do
        c = Contact.new(:first_name => "El", :last_name => "Barto")
        c.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071")
        c.check_duplicates = false
        c.should_not be_valid
      end
      specify "same contact can have duplicated mobile (they may be visible to different accounts)" do
        @bart.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071")
        @bart.check_duplicates = false
        @bart.should be_valid
      end
      specify "different mobile phones should be fine" do
        c = Contact.new(:first_name => "El", :last_name => "Barto")
        c.contact_attributes << Telephone.new(:category => :mobile, :value => "1540993333")
        c.check_duplicates = false
        c.should be_valid
      end
      describe "and Telephone#allow_duplicate is true" do
        it "allows mobile to be duplicate" do
          c = Contact.new(:first_name => "El", :last_name => "Barto")
          c.contact_attributes << Telephone.new(category: :mobile, value: "1540995071", allow_duplicate: true)
          c.check_duplicates = false
          c.should be_valid
        end
        specify "same contact can have duplicated mobile (they may be visible to different accounts)" do
          @bart.contact_attributes << Telephone.new(:category => :mobile, :value => "1540995071", allow_duplicate: true)
          @bart.check_duplicates = false
          @bart.should be_valid
        end
        specify "different mobile phones should be fine" do
          c = Contact.new(:first_name => "El", :last_name => "Barto")
          c.contact_attributes << Telephone.new(:category => :mobile, :value => "1540993333", allow_duplicate: true)
          c.check_duplicates = false
          c.should be_valid
        end
      end
    end

  end

  specify "categories other than 'mobile' shouldn't be unique'" do
    c = Contact.new(:first_name => "Bartman")
    c.contact_attributes << Telephone.new(:category => :home, :value => "1540995071")
    c.should be_valid
  end

end
