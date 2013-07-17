# encoding: UTF-8
require 'spec_helper'

describe BirthdayNotificator do
  describe "getting all contacts whose birthday is today" do
    before do
      @ac1 = Account.make
      @ac2 = Account.make
      @first_contact = Contact.make(owner: @ac1, gender: 'male')
      @first_contact.local_unique_attributes <<  LocalStatus.make(account: @ac1, value: 'student')
      @first_contact.contact_attributes << DateAttribute.new(
                                  year: 1982,
                                  month: Date.today.month,
                                  day: Date.today.day,
                                  category: 'birthday')
      @second_contact = Contact.make(owner: @ac2)
      @second_contact.contact_attributes << DateAttribute.new(
                                  month: Date.today.month,
                                  day: Date.today.day,
                                  category: 'birthday')
      @second_contact.local_unique_attributes <<  LocalStatus.make(account: @ac2, value: 'prospect')
      @third_contact = Contact.make(owner: @ac1)
      @third_contact.contact_attributes << DateAttribute.new(
                                  year: 1982,
                                  month: Date.today.month,
                                  day: Date.yesterday.day,
                                  category: 'birthday')
      @third_contact.local_unique_attributes <<  LocalStatus.make(account: @ac1, value: 'prospect')
      @first_contact.save
      @second_contact.save
      @third_contact.save
    end
    it "should get all birthdays" do
      bn = BirthdayNotificator.new
      bn.all_birthdays.count.should == 2
    end

    it "should send a correct json string" do
      bn = BirthdayNotificator.new
      contact = @first_contact
      json_contact = bn.json_for(contact)
      puts "#{json_contact}"
      json_contact[:gender].should == 'male'
      json_contact["local_status_for_#{@ac1.name}"].should == :student
    end
  end
end