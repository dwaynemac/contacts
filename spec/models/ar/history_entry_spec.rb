# encoding: UTF-8
require 'ar_spec_helper'

describe NewHistoryEntry do
  it { should respond_to(:historiable_type, :historiable_id, :changed_at, :attr, :old_value) }
  
  describe "#value_at" do
    let(:contact){NewContact.make(level: NewContact::VALID_LEVELS[3])}
    it "should return nil if there is no record in history" do
      contact.history_entries.value_at(:level, 1.month.ago.to_time).should be_nil
    end
    it "should return value at given date if found" do
      contact.history_entries.create(attr: :level,
                                     old_value: NewContact::VALID_LEVELS[0],
                                     changed_at: 3.weeks.ago.to_time)
      contact.history_entries.create(attr: :level,
                                     old_value: NewContact::VALID_LEVELS[1],
                                     changed_at: 2.weeks.ago.to_time)
      contact.history_entries.create(attr: :level,
                                     old_value: NewContact::VALID_LEVELS[2],
                                     changed_at: 1.week.ago.to_time)
      contact.history_entries.value_at(:level, 10.days.ago).should  == NewContact::VALID_LEVELS[2]
      contact.history_entries.value_at(:level, 15.days.ago).should  == NewContact::VALID_LEVELS[1]
      contact.history_entries.value_at(:level, 2.days.ago).should   be_nil
      contact.history_entries.value_at(:level, 1.month.ago).should  == NewContact::VALID_LEVELS[0]
      contact.history_entries.value_at(:other_attribute, 1.day.ago).should be_nil
    end
  end

  describe "#last_value" do
    let(:contact){NewContact.make(level: NewContact::VALID_LEVELS[3])}
    it "should return nil if there is no record in history" do
      contact.history_entries.last_value(:level).should be_nil
    end
    it "should return last value if found" do
      contact.history_entries.create(attr: :level,
                                     old_value: NewContact::VALID_LEVELS[0],
                                     changed_at: 3.weeks.ago.to_time)
      contact.history_entries.create(attr: :level,
                                     old_value: NewContact::VALID_LEVELS[1],
                                     changed_at: 2.weeks.ago.to_time)
      contact.history_entries.create(attr: :level,
                                     old_value: NewContact::VALID_LEVELS[2],
                                     changed_at: 1.week.ago.to_time)
      contact.history_entries.last_value(:level).should  == NewContact::VALID_LEVELS[2]
    end
  end


  describe "#element_ids_with" do
    before do
      Rails.cache.clear
    end

    context "when option class" do
      let(:contact_without_history){NewContact.make(level: 'aspirante')}
      let(:contact_with_history){NewContact.make(level: 'aspirante')}

      before do
        contact_without_history.history_entries.delete_all

        contact_with_history.history_entries.delete_all
        contact_with_history.history_entries.create(attr: 'level', old_value: NewContact::VALID_LEVELS['sádhaka'], changed_at: 1.month.ago.to_time)
      end

      context "is given" do
        it "should include elements without history" do
          eids = NewHistoryEntry.element_ids_with(level: NewContact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago,
                                        class: 'NewContact')
          contact_without_history.id.in?(eids).should be_truthy
        end
        it "should not include elements that currently have desired value but didnt on given date" do
          eids = NewHistoryEntry.element_ids_with(level: NewContact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago,
                                        class: 'NewContact')
          contact_with_history.id.in?(eids).should be_falsy
        end
      end
      context "is NOT given" do
        it "should not include elements without history" do
          eids = NewHistoryEntry.element_ids_with(level: NewContact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago)
          contact_without_history.id.in?(eids).should be_falsy
        end
        it "should not include elements that currently have desired value but didnt on given date" do
          eids = NewHistoryEntry.element_ids_with(level: NewContact::VALID_LEVELS['aspirante'],
                                        at: 1.year.ago)
          contact_with_history.id.in?(eids).should be_falsy
        end
      end
    end

    it "should ignore other attr entries" do
      c = NewContact.make(level: 'sádhaka')
      # this one should be ignored for its attr
      c.history_entries.create(attr: :level,  old_value: 'student', changed_at: 1.month.ago.to_time)

      eids = NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'NewContact')
      c.id.in?(eids).should be_falsy
    end

    it "should ignore other class entries" do
      NewHistoryEntry.create(historiable_type: 'OtherClass',
                          historiable_id: 'ignore-me',
                          attr: :status,
                          old_value: 'student',
                          changed_at: 1.month.ago.to_time)

      eids = NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)
      'ingore-me'.in?(eids).should be_falsy
    end

    it "should get value at given date" do
      s = NewContact.make(status: :student)
      s.history_entries.create(attr: :status, old_value: :former_student,  changed_at: 1.month.ago.to_time)
      s.history_entries.create(attr: :status, old_value: :student,         changed_at: 3.weeks.ago.to_time)
      s.history_entries.create(attr: :status, old_value: :former_student,  changed_at: 1.week.ago.to_time)

      fs = NewContact.make(status: :former_student)
      fs.history_entries.create(attr: :status, old_value: :student,         changed_at: 3.weeks.ago.to_time)

      res = NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)
      fs.id.in?(res).should be_truthy
      s.id.in?(res).should be_falsy
    end

    it "should get value at limit dates" do
      s = NewContact.make(level: 'aspirante')
      s.history_entries.delete_all
      s.history_entries.create(attr: 'level', old_value: nil, changed_at: "2015-10-31 14:35".to_time(:utc))
      res = NewHistoryEntry.element_ids_with(level: NewContact::VALID_LEVELS['aspirante'], at: "2015-10-31", class: 'NewContact')
      s.id.in?(res).should be_truthy
    end

    context "attr: :status" do
      it "should returns elements without history entries after specified date that currently match expected attr" do
        s = NewContact.make(status: :student)
        s.history_entries.create(attr: :status, old_value: :former_student,  changed_at: 1.month.ago.to_time)

        cs = NewContact.make(status: :student, owner: NewAccount.make(name: 'account'))
        cs.history_entries.delete_all

        res = NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'NewContact')
        cs.id.in?(res).should be_truthy
      end
    end
    context "with attr :local_status_for_accountName" do

      let(:contact){ NewContact.make }

      before do
        NewContact.skip_callback :save, :after, :keep_history_of_changes
        LocalStatus.skip_callback(:save, :after, :keep_history_of_changes)
        LocalTeacher.skip_callback(:save, :after, :keep_history_of_changes)

        s = NewContact.make
        s.history_entries.create(attr: :local_status_for_accountname, old_value: :student,  changed_at: 1.month.ago.to_time)

        contact.local_unique_attributes << LocalStatus.new(value: 'student', account: NewAccount.make(name: 'accountname'))
      end


      it "returns elements without history entries after specified date that currently match expected attr" do
        res = NewHistoryEntry.element_ids_with(local_status_for_accountname: 'student', at: Date.civil(2012,12,20).to_time, class: 'NewContact')
        contact.id.in?(res).should be_truthy
      end
    end


    it "should not include this object" do
      s = NewContact.make(status: :student)
      s.history_entries.delete_all
      s.history_entries.should == []
      s.history_entries.create(attr: :status, old_value: :prospect,  changed_at: 1.month.ago.to_time)
      s.history_entries.create(attr: :status, old_value: :former_student,  changed_at: 20.days.ago.to_time)
      s.history_entries.count.should == 2

      res = NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'NewContact')
      s.in?(res).should be_falsy
    end

    context "filters by account" do
      before do
        account = NewAccount.make
        cs = NewContact.make(status: :student, owner: account)
        account.link(cs) # this shouldn't be necessary
        cs.history_entries.delete_all

        other_account = NewAccount.make
        other_acc_cs = NewContact.make(status: :student, owner: other_account)
        other_account.link(other_acc_cs)
        other_acc_cs.history_entries.delete_all

        fs = NewContact.make(status: :former_student, owner: account)
        fs.history_entries.create(attr: :status, old_value: :student, changed_at: 3.weeks.ago.to_time)

        ofs = NewContact.make(status: :former_student, owner: other_account)
        ofs.history_entries.create(attr: :status, old_value: :student,changed_at: 3.weeks.ago.to_time)

        @cs = cs
        @fs = fs
        @ocs = other_acc_cs
        @ofs = ofs
        @account = account
      end
      context "with account_name" do
        subject { NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'NewContact', account_name: @account.name) }
        it "includes account's elements with desired value in desired moment" do
          @fs.id.in?(subject).should be_truthy
        end
        it "includes account's elements without history with desired value" do
          @cs.id.in?(subject).should be_truthy
        end
        it "doesnt include other accounts elements with desired value in desired moment" do
          @ofs.in?(subject).should be_falsy
        end
        it "doesnt include other accounts elements without history with desired value" do
          @ocs.id.in?(subject).should be_falsy
        end
      end
      context "with account" do
        subject { NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago, class: 'NewContact', account: @account) }
        it "includes account's elements with desired value in desired moment" do
          @fs.id.in?(subject).should be_truthy
        end
        it "includes account's elements without history with desired value" do
          @cs.id.in?(subject).should be_truthy
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
      expect{NewHistoryEntry.element_ids_with(status: 'student', at: 2.months.ago)}.not_to raise_error
    end
  end
end
