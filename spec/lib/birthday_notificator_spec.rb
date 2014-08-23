# encoding: UTF-8
require 'spec_helper'

describe BirthdayNotificator do

  let(:bn){BirthdayNotificator.new}

  before do
    @ac1 = Account.make
    @ac2 = Account.make

    @first_contact = Contact.make(owner: @ac1, gender: 'male')
    @first_contact.local_unique_attributes <<  LocalStatus.make(account: @ac1,
                                                                value: 'student')
    @first_contact.local_unique_attributes <<  Coefficient.new(account: @ac1,
                                                               value: 'perfil')
    @first_contact.contact_attributes << DateAttribute.new(
        year: 1982,
        month: Date.today.month,
        day: Date.today.day,
        category: 'birthday')
    @first_contact.contact_attributes << Email.new(value: 'dwaynemac@gmail.com')

    @second_contact = Contact.make(owner: @ac2)
    @second_contact.contact_attributes << DateAttribute.new(
        month: Date.today.month,
        day: Date.today.day,
        category: 'birthday')
    @second_contact.local_unique_attributes <<  LocalStatus.make(account: @ac2,
                                                                 value: 'prospect')

    @third_contact = Contact.make(owner: @ac1)
    @third_contact.contact_attributes << DateAttribute.new(
        year: 1982,
        month: Date.today.month,
        day: Date.yesterday.day,
        category: 'birthday')
    @third_contact.local_unique_attributes <<  LocalStatus.make(account: @ac1,
                                                                value: 'prospect')

    @first_contact.save
    @second_contact.save
    @third_contact.save
  end

  describe "#deliver_notifications" do
    it "broadcasts #all_birthdays to messaging" do
      Messaging::Client.should_receive('post_message')
                       .with('birthday',anything())
                       .exactly(bn.all_birthdays.count).times
                       .and_return true
      bn.deliver_notifications 
    end
    it "boradcasts #json_for of each contact" do
      bn.all_birthdays.each do |contact|
        Messaging::Client.should_receive('post_message')
                         .with('birthday',bn.json_for(contact))
                         .and_return true
      end
      bn.deliver_notifications
    end
  end

  describe "#all_birthdays" do
    it "should get all birthdays" do
      bdays = bn.all_birthdays
      bdays.to_a.should == [@first_contact, @second_contact]
      bn.all_birthdays.count.should == 2
    end
  end

  describe "#json_for" do
    context "for contact with email" do
      let(:json) { bn.json_for(@first_contact) }
      it 'includes linked accounts' do
        json[:linked_accounts_names].should == [@ac1.name]
      end
      it('includes gender') do
        json[:gender].should == 'male'
      end
      it "includes local_status_for_AccountName" do
        json["local_status_for_#{@ac1.name}"].should == :student
      end
      it("includes primary email") do
        json[:recipient_email].should == 'dwaynemac@gmail.com'
      end
      it "includes coefficients" do
        json["local_coefficient_for_#{@ac1.name}"].should == 'perfil'
      end
    end
    context "for contact without email" do
      let(:json) { bn.json_for(@second_contact) }
      it("wont raise exceptions") { expect { json }.not_to raise_exception }
    end
  end
end
