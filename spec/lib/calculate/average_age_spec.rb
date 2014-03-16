require 'spec_helper'

describe Calculate::AverageAge do
  
  describe "#contacts" do
    it "accepts an array of contacts" do
      contacts = []
      # age 30
      contacts << contact_with( birthday: { year: 1983, month: 5, day: 21 } )
      # age nil
      contacts << contact_with( birthday: { month: 12, day: 1 })
      # age 20
      contacts << contact_with( estimated_age: 17, on: Date.civil(2011,3,16) )
      # age 17
      contacts << contact_with( estimated_age: 17, on: nil)
      caa = Calculate::AverageAge.new ref_date: Date.civil(2014,3,16), contacts: contacts
      caa.ages.should == [30, 20, 17]
    end
    it "accepts a Mongoid::Criteria" do
      Contact.delete_all
      # age 30
      contact_with( birthday: { year: 1983, month: 5, day: 21 } )
      # age nil
      contact_with( birthday: { month: 12, day: 1 })
      # age 20
      contact_with( estimated_age: 17, on: Date.civil(2011,3,16) )
      # age 17
      contact_with( estimated_age: 17, on: nil)
      caa = Calculate::AverageAge.new ref_date: Date.civil(2014,3,16), contacts: Contact.all
      caa.ages.should == [30, 20, 17]
    end
  end

  describe "#ages" do
    it "returns an array of ages of contacts collection" do
      contacts = []
      # age 30
      contacts << contact_with( birthday: { year: 1983, month: 5, day: 21 } )
      # age nil
      contacts << contact_with( birthday: { month: 12, day: 1 })
      # age 20
      contacts << contact_with( estimated_age: 17, on: Date.civil(2011,3,16) )
      # age 17
      contacts << contact_with( estimated_age: 17, on: nil)
      caa = Calculate::AverageAge.new ref_date: Date.civil(2014,3,16), contacts: contacts
      caa.ages.should == [30, 20, 17]
    end
  end

  describe "#get_age_for" do
    it "returns nil if age results < 0" do
      @contact = contact_with estimated_age: 17, on: Date.civil(2011,3,16)
      caa = Calculate::AverageAge.new ref_date: Date.civil(1000,3,16)
      caa.get_age_for(@contact).should be_nil
    end
    describe "contact with birthday" do
      describe "with year" do
        before do
          @contact = contact_with birthday: { year: 1983, month: 5, day: 21 }
        end
        it "return age according to birthday" do
          caa = Calculate::AverageAge.new ref_date: Date.civil(2014,5,22)
          caa.get_age_for(@contact).should == 31
        end
      end
      describe "without year" do
        before do
          @contact = contact_with birthday: { month: 12, day: 1 }
        end
        it "returns nil" do
          caa = Calculate::AverageAge.new
          caa.get_age_for(@contact).should be_nil
        end
      end
    end
    describe "contact with estimated_age and estimated_age_on" do
      before do
        @contact = contact_with estimated_age: 17, on: Date.civil(2011,3,16) 
      end
      it "returns age using estimated_age and offset from day it was estimated on" do
        caa = Calculate::AverageAge.new ref_date: Date.civil(2014,3,16)
        caa.get_age_for(@contact).should == 20
      end
    end
    describe "contact with estimated_age but no estimated_age_on" do
      before do
        @contact = contact_with estimated_age: 17, on: nil
      end
      it "returns estimated_age" do
        caa = Calculate::AverageAge.new ref_date: Date.civil(2014,3,16)
        caa.get_age_for(@contact).should == 17
      end
    end
  end
end

def contact_with(options)
  c = Contact.make
  if options[:birthday]
    da = DateAttribute.new(category: 'birthday',
                           year: options[:birthday][:year],
                           month: options[:birthday][:month],
                           day: options[:birthday][:day])
    c.contact_attributes << da
    c.save!
    c
  elsif options[:estimated_age]
    c.estimated_age = options[:estimated_age]
    Date.stub(:today).once.and_return options[:on]
    c.save!
    c.estimated_age_on.should == options[:on]
    c
  end
end
