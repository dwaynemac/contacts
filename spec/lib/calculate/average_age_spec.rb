require 'spec_helper'

describe Calculate::AverageAge do
  describe "#get_age_for" do
    describe "contact with birthday" do
      describe "with year" do
        before do
          c = Contact.make
          da = DateAttribute.new(category: 'birthday', year: 1983, month: 5, day: 21)
          c.contact_attributes << da
          c.save!
          @contact = c
        end
        it "return age according to birthday" do
          caa = Calculate::AverageAge.new ref_date: Date.civil(2014,5,22)
          caa.get_age_for(@contact).should == 31
        end
      end
      describe "without year" do
        before do
          c = Contact.make
          da = DateAttribute.new(category: 'birthday', month: 12, day: 1)
          c.contact_attributes << da
          c.save!
          @contact = c
        end
        it "returns nil" do
          caa = Calculate::AverageAge.new
          caa.get_age_for(@contact).should be_nil
        end
      end
    end
    describe "contact with estimated_age and estimated_age_on" do
      before do
        @contact = Contact.make
        Date.stub(:today).once.and_return Date.civil(2011,3,16)
        @contact.estimated_age = 17
        @contact.save!
        @contact.estimated_age_on.should == Date.civil(2011,3,16)
      end
      it "returns age using estimated_age and offset from day it was estimated on" do
        caa = Calculate::AverageAge.new ref_date: Date.civil(2014,3,16)
        caa.get_age_for(@contact).should == 20
      end
    end
    describe "contact with estimated_age but no estimated_age_on" do
      before do
        @contact = Contact.make(estimated_age: 17)
        @contact.estimated_age_on = nil
        @contact.save!
        @contact.estimated_age_on.should be_nil
      end
      it "returns estimated_age" do
        caa = Calculate::AverageAge.new ref_date: Date.civil(2014,3,16)
        caa.get_age_for(@contact).should == 17
      end
    end
  end
end
