require File.dirname(__FILE__) + '/../spec_helper'

describe Identification do
  it { should validate_presence_of :value }

  it "should always be public" do
    @bart = Contact.make(:first_name => "Bart", :last_name => "Simpson")
    @bart.contact_attributes << Identification.new(:category => :dni, :value => "30366832", :public => false)
    @bart.save
    @bart.reload
    @bart.contact_attributes.last.should be_public
  end

  it "allows two contacts to have same [category, value]" do
    @bart = Contact.make(:first_name => "Bart", :last_name => "Simpson")
    @bart.contact_attributes << Identification.new(:category => :dni, :value => "30366832")
    @bart.save

    c = Contact.new(:first_name => "El", :last_name => "Barto")
    c.contact_attributes << Identification.new(:category => :dni, :value => "30366832")
    c.should be_valid
  end

  describe "should validate that contacts have only one Identification of each name (type of id)" do
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
