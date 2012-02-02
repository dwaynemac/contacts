# encoding: UTF-8
require 'spec_helper'

describe HistoryEntry do
  it { should have_field(:historiable_type) }
  it { should have_field(:historiable_id) }
  it { should have_field(:changed_at) }
  it { should have_field(:attribute) }
  it { should have_field(:old_value) }

  describe "#value_at" do
    let(:contact){Contact.make(level: Contact::VALID_LEVELS[3])}
    it "should return nil if there is no record in history" do
      contact.history_entries.value_at(:level, 1.month.ago.to_time).should be_nil
    end
    it "should return value at given date if found" do
      contact.history_entries.create(attribute: :level,
                                     old_value: Contact::VALID_LEVELS[0],
                                     changed_at: 3.weeks.ago.to_time)
      contact.history_entries.create(attribute: :level,
                                     old_value: Contact::VALID_LEVELS[1],
                                     changed_at: 2.weeks.ago.to_time)
      contact.history_entries.create(attribute: :level,
                                     old_value: Contact::VALID_LEVELS[2],
                                     changed_at: 1.week.ago.to_time)
      contact.history_entries.value_at(:level, 10.days.ago).should  == Contact::VALID_LEVELS[2]
      contact.history_entries.value_at(:level, 15.days.ago).should  == Contact::VALID_LEVELS[1]
      contact.history_entries.value_at(:level, 2.days.ago).should   be_nil
      contact.history_entries.value_at(:level, 1.month.ago).should  == Contact::VALID_LEVELS[0]
      contact.history_entries.value_at(:other_attribute, 1.day.ago).should be_nil
    end
  end

  describe "#element_ids_with" do

    it "should ignore other attribute entries" do
      c = Contact.make(level: 'sádhaka')
      # this one should be ignored for its attribute
      c.history_entries.create(attribute: :level,  old_value: 'student',        changed_at: 1.month.ago.to_time)

      HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago).should_not include(c._id)
    end

    it "should ignore other class entries" do
      HistoryEntry.create(historiable_type: 'OtherClass',
                          historiable_id: 'ignore-me',
                          attribute: :status,
                          old_value: 'student',
                          changed_at: 1.month.ago.to_time)

      HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago).should_not include('ingore-me')
    end

    it "should get value at given date" do
      s = Contact.make(status: :student)
      s.history_entries.create(attribute: :status, old_value: :former_student,  changed_at: 1.month.ago.to_time)
      s.history_entries.create(attribute: :status, old_value: :student,         changed_at: 3.weeks.ago.to_time)
      s.history_entries.create(attribute: :status, old_value: :former_student,  changed_at: 1.week.ago.to_time)

      fs = Contact.make(status: :former_student)
      fs.history_entries.create(attribute: :status, old_value: :student,         changed_at: 3.weeks.ago.to_time)

      res = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)
      res.should include(fs._id)
      res.should_not include(s._id)
    end

    it "should returns elements without history entries after specified date that currently match expected attribute" do
      s = Contact.make(status: :student)
      s.history_entries.create(attribute: :status, old_value: :former_student,  changed_at: 1.month.ago.to_time)

      cs = Contact.make(status: :student, owner: Account.make(name: 'account'))

      res = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'Contact')
      res.should include(cs._id)
    end

    it "should scope to account if specified" do
      account = Account.make
      cs = Contact.make(status: :student, owner: account)
      account.link(cs) # this shouldn't be necessary
      other_account = Account.make
      other_acc_cs = Contact.make(status: :student, owner: other_account)
      other_account.link(other_acc_cs)

      fs = Contact.make(status: :former_student, owner: account)
      fs.history_entries.create(attribute: :status, old_value: :student, changed_at: 3.weeks.ago.to_time)
      ofs = Contact.make(status: :former_student, owner: other_account)
      ofs.history_entries.create(attribute: :status, old_value: :student,changed_at: 3.weeks.ago.to_time)

      res = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'Contact', account_name: account.name)

      res.should include(cs._id)
      res.should include(fs._id)
      res.should_not include(other_acc_cs._id)
      res.should_not include(ofs._id)
    end

    it "should no raise exception when there are no records" do
      expect{HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)}.not_to raise_error
    end
  end
end
