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

  describe "on #update" do
    context "value is being changed" do
      context "and email is primary" do
        before do
          @c = Contact.make(:first_name => "Bart", :last_name => "Simpson")
          @c.contact_attributes << Email.new(:category => :personal, :value => "bart@thesimpsons.com")
          @c.save!
          @c.contact_attributes.first.value = "bart2@thesimpsons.com"
        end
        it "should call update_contact_in_mailchimp with previous value" do
          @c.contact_attributes.first.primary.should be_truthy
          Contact.any_instance.should_receive(:update_contact_in_mailchimp).with().once
          Contact.any_instance.should_receive(:update_contact_in_mailchimp).with("bart@thesimpsons.com").once
          @c.save
          @c.contact_attributes.first.value.should == "bart2@thesimpsons.com"
        end
      end
      context "and email is not primary" do
        before do
          @c = Contact.make(:first_name => "Bart", :last_name => "Simpson")
          @c.contact_attributes << Email.new(:category => :personal, :value => "bart@thesimpsons.com")
          @c.contact_attributes << Email.new(:category => :personal, :value => "maggie@thesimpsons.com")
          @c.save!
          @c.contact_attributes.last.value = "maggie2@thesimpsons.com"
        end
        it "should not call update_contact_in_mailchimp with previous value" do
          @c.contact_attributes.first.primary.should be_truthy
          @c.contact_attributes.last.primary.should be_falsy
          Contact.any_instance.should_receive(:update_contact_in_mailchimp).with().once
          Contact.any_instance.should_not_receive(:update_contact_in_mailchimp).with("maggie2@thesimpsons.com")
          @c.save
          @c.contact_attributes.last.value.should == "maggie2@thesimpsons.com"
        end
      end
    end
  end

  describe "on #delete" do
    before do
      @c = Contact.make(:first_name => "Bart", :last_name => "Simpson")
      @c.contact_attributes << Email.new(:category => :personal, :value => "bart@thesimpsons.com")
      @c.contact_attributes << Email.new(:category => :personal, :value => "maggie@thesimpsons.com")
      @c.save!
    end
    context "email is primary" do
      it "should unsubscribe contact from mailchimp" do
        Contact.any_instance.should_receive(:delete_contact_from_mailchimp).with("bart@thesimpsons.com")
        @c.contact_attributes.first.destroy
      end
    end
    context "email is not primary" do
      it "should not unsubscribe contact from mailchimp" do
        Contact.any_instance.should_not_receive(:delete_contact_from_mailchimp)
        @c.contact_attributes.last.destroy
      end
    end
  end
end
