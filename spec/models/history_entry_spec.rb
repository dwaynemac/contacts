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

  describe "#last_value" do
    let(:contact){Contact.make(level: Contact::VALID_LEVELS[3])}
    it "should return nil if there is no record in history" do
      contact.history_entries.last_value(:level).should be_nil
    end
    it "should return last value if found" do
      contact.history_entries.create(attribute: :level,
                                     old_value: Contact::VALID_LEVELS[0],
                                     changed_at: 3.weeks.ago.to_time)
      contact.history_entries.create(attribute: :level,
                                     old_value: Contact::VALID_LEVELS[1],
                                     changed_at: 2.weeks.ago.to_time)
      contact.history_entries.create(attribute: :level,
                                     old_value: Contact::VALID_LEVELS[2],
                                     changed_at: 1.week.ago.to_time)
      contact.history_entries.last_value(:level).should  == Contact::VALID_LEVELS[2]
    end
  end


  describe "#element_ids_with" do
    before do
      Rails.cache.clear
    end

    context "when option class" do
      let(:contact_without_history){Contact.make(level: 'aspirante')}
      let(:contact_with_history){Contact.make(level: 'aspirante')}

      before do
        contact_without_history.history_entries.delete_all

        contact_with_history.history_entries.delete_all
        contact_with_history.history_entries.create(attribute: 'level', old_value: Contact::VALID_LEVELS['sádhaka'], changed_at: 1.month.ago.to_time)
      end

      context "is given" do
        it "should include elements without history" do
          eids = HistoryEntry.element_ids_with(level: Contact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago,
                                        class: 'Contact')
          contact_without_history.id.in?(eids).should be_truthy
        end
        it "should not include elements that currently have desired value but didnt on given date" do
          eids = HistoryEntry.element_ids_with(level: Contact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago,
                                        class: 'Contact')
          contact_with_history.id.in?(eids).should be_falsy
        end
      end
      context "is NOT given" do
        it "should not include elements without history" do
          eids = HistoryEntry.element_ids_with(level: Contact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago)
          contact_without_history.id.in?(eids).should be_falsy
        end
        it "should not include elements that currently have desired value but didnt on given date" do
          eids = HistoryEntry.element_ids_with(level: Contact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago)
          contact_with_history.id.in?(eids).should be_falsy
        end
      end
    end

    it "should ignore other attribute entries" do
      c = Contact.make(level: 'sádhaka')
      # this one should be ignored for its attribute
      c.history_entries.create(attribute: :level,  old_value: 'student', changed_at: 1.month.ago.to_time)

      eids = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'Contact')
      c._id.in?(eids).should be_falsy
    end

    it "should ignore other class entries" do
      HistoryEntry.create(historiable_type: 'OtherClass',
                          historiable_id: 'ignore-me',
                          attribute: :status,
                          old_value: 'student',
                          changed_at: 1.month.ago.to_time)

      eids = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)
      'ingore-me'.in?(eids).should be_falsy
    end

    it "should get value at given date" do
      s = Contact.make(status: :student)
      s.history_entries.create(attribute: :status, old_value: :former_student,  changed_at: 1.month.ago.to_time)
      s.history_entries.create(attribute: :status, old_value: :student,         changed_at: 3.weeks.ago.to_time)
      s.history_entries.create(attribute: :status, old_value: :former_student,  changed_at: 1.week.ago.to_time)

      fs = Contact.make(status: :former_student)
      fs.history_entries.create(attribute: :status, old_value: :student,         changed_at: 3.weeks.ago.to_time)

      res = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)
      fs._id.in?(res).should be_truthy
      s._id.in?(res).should be_falsy
    end

    context "attribute: :status" do
      it "should returns elements without history entries after specified date that currently match expected attribute" do
        s = Contact.make(status: :student)
        s.history_entries.create(attribute: :status, old_value: :former_student,  changed_at: 1.month.ago.to_time)

        cs = Contact.make(status: :student, owner: Account.make(name: 'account'))
        cs.history_entries.delete_all

        res = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'Contact')
        cs._id.in?(res).should be_truthy
      end
    end
    context "with attribute :local_status_for_accountName" do

      let(:contact){ Contact.make }

      before do
        Contact.skip_callback :save, :after, :keep_history_of_changes
        LocalStatus.skip_callback(:save, :after, :keep_history_of_changes)
        LocalTeacher.skip_callback(:save, :after, :keep_history_of_changes)

        s = Contact.make
        s.history_entries.create(attribute: :local_status_for_accountname, old_value: :student,  changed_at: 1.month.ago.to_time)

        contact.local_unique_attributes << LocalStatus.new(value: 'student', account: Account.make(name: 'accountname'))
      end


      it "returns elements without history entries after specified date that currently match expected attribute" do
        res = HistoryEntry.element_ids_with(local_status_for_accountname: 'student', at: Date.civil(2012,12,20).to_time, class: 'Contact')
        contact._id.in?(res).should be_truthy
      end
    end


    it "should not include this object" do
      s = Contact.make(status: :student)
      s.history_entries.delete_all
      s.history_entries.should == []
      s.history_entries.create(attribute: :status, old_value: :prospect,  changed_at: 1.month.ago.to_time)
      s.history_entries.create(attribute: :status, old_value: :former_student,  changed_at: 20.days.ago.to_time)
      s.history_entries.count.should == 2

      res = HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'Contact')
      s.in?(res).should be_falsy
    end

    context "filters by account" do
      before do
        account = Account.make
        cs = Contact.make(status: :student, owner: account)
        account.link(cs) # this shouldn't be necessary
        cs.history_entries.delete_all

        other_account = Account.make
        other_acc_cs = Contact.make(status: :student, owner: other_account)
        other_account.link(other_acc_cs)
        other_acc_cs.history_entries.delete_all

        fs = Contact.make(status: :former_student, owner: account)
        fs.history_entries.create(attribute: :status, old_value: :student, changed_at: 3.weeks.ago.to_time)

        ofs = Contact.make(status: :former_student, owner: other_account)
        ofs.history_entries.create(attribute: :status, old_value: :student,changed_at: 3.weeks.ago.to_time)

        @cs = cs
        @fs = fs
        @ocs = other_acc_cs
        @ofs = ofs
        @account = account
      end
      context "with account_name" do
        subject { HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'Contact', account_name: @account.name) }
        it "includes account's elements with desired value in desired moment" do
          @fs._id.in?(subject).should be_truthy
        end
        it "includes account's elements without history with desired value" do
          @cs._id.in?(subject).should be_truthy
        end
        it "doesnt include other accounts elements with desired value in desired moment" do
          @ofs.in?(subject).should be_falsy
        end
        it "doesnt include other accounts elements without history with desired value" do
          @ocs.id.in?(subject).should be_falsy
        end
      end
      context "with account" do
        subject { HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'Contact', account: @account) }
        it "includes account's elements with desired value in desired moment" do
          @fs._id.in?(subject).should be_truthy
        end
        it "includes account's elements without history with desired value" do
          @cs._id.in?(subject).should be_truthy
        end
        it "doesnt include other accounts elements with desired value in desired moment" do
          @ofs.in?(subject).should be_falsy
        end
        it "doesnt include other accounts elements without history with desired value" do
          @ocs.id.in?(subject).should be_falsy
        end
      end
    end

    pending "should not raise exception when there are no records" do
      expect{HistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)}.not_to raise_error
    end
  end
end
