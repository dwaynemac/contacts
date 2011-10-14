require File.dirname(__FILE__) + '/../spec_helper'

describe Identification do
  it { should validate_presence_of :value }

  describe "should be unique" do
    before do
      @bart = Contact.make(:first_name => "Bart", :last_name => "Simpson")
      @bart.contact_attributes << Identification.new(:category => :dni, :value => "30366832")
      @bart.save
    end
    specify " so two contacts cant have same identity" do
      c = Contact.new(:first_name => "El", :last_name => "Barto")
      c.contact_attributes << Identification.new(:category => :dni, :value => "30366832")
      c.should_not be_valid
    end
    specify " scoping to category" do
      c = Contact.new(:first_name => "Bartman")
      c.contact_attributes << Identification.new(:category => :cpf, :value => "30366832")
      c.should be_valid
    end
  end

  describe "should validate that contacts have only one Identification of each category" do
    before do
      @c = Contact.make(:first_name => "Bartolomeo")
    end
    specify ". So contact cant have two dni" do
      @c.contact_attributes << Identification.new(:category => :dni, :value => "a")
      @c.contact_attributes << Identification.new(:category => :dni, :value => "b")
      @c.should_not be_valid
    end
    specify "but two contacts may have dni" do
      c2 = Contact.make(:first_name => "Bartolomeo")
      @c.contact_attributes << Identification.new(:category => :dni, :value => "a")
      c2.contact_attributes << Identification.new(:category => :dni, :value => "b")
      @c.should be_valid
      c2.should be_valid
    end
    specify "but a contact may have different Identifications" do
      @c.contact_attributes << Identification.new(:category => :dni, :value => "a")
      @c.contact_attributes << Identification.new(:category => :cpf, :value => "a")
      @c.should be_valid
    end
  end
end