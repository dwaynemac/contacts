require File.dirname(__FILE__) + '/../../spec_helper'

describe StudentsCount do

  let(:account_a){Account.make}
  let(:account_b){Account.make}

  describe ".calculate" do
    before do

      Contact.make # non student

      quick_create 5,   'students', in_account: account_a, with_teacher: 'teacher-1'
      quick_create 2,   'students', in_account: account_a, with_teacher: 'teacher-2'

      quick_create 34,  'students', in_account: account_b, with_teacher: 'teacher-3'
      quick_create 1,   'student',  in_account: account_b, with_teacher: 'teacher-1'

    end
    context 'when not scoped' do
      it "counts all students" do
        StudentsCount.calculate.should == 42
      end

    end
    context "with teacher_name option" do
      it "returns teachers students across all accounts" do
        StudentsCount.calculate(teacher_name: 'teacher-1').should == 6
      end
      context "with :year" do
        it "returns teachers students at the end of the year across all accounts"
        context "with :month" do
          it "returns teachers students at the end of the month across all accounts"
        end
      end
    end
    context "with account_name option" do
      specify{ StudentsCount.calculate(account_name: account_a.name).should == 7 }
      context "and teacher_name option" do
        specify{ StudentsCount.calculate(account_name: account_a.name, teacher_name: 'teacher-1').should == 5 }
      end
      context "with :year option" do
        let(:history_account){Account.make(name: 'history_account')}
        before do
          HistoryEntry.delete_all

          Contact.skip_callback :save, :after, :keep_history_of_changes
          LocalStatus.skip_callback(:save, :after, :keep_history_of_changes)
          LocalTeacher.skip_callback(:save, :after, :keep_history_of_changes)

          quick_create 1, 'former_student', in_account: history_account, with_teacher: 't1', old_st: 'student', st_until: Date.civil(2013,1,1)
          quick_create 1, 'former_student', in_account: history_account, with_teacher: 't1', old_st: 'student',st_until: Date.civil(2012,12,1)
          quick_create 1, 'former_student', in_account: history_account, with_teacher: 't1', old_st: 'student',st_until: Date.civil(2012,11,1)
          quick_create 1, 'student', in_account: history_account, with_teacher: 't3', old_tch: 't2', tch_until: Date.civil(2012,10,1)


        end

        it "returns count at the last day of the year" do
          StudentsCount.calculate(year: 2012, account_name: history_account.name).should == 2
        end

        context "and :teacher_name" do
          specify { StudentsCount.calculate(year: 2012, account_name: 'history_account', teacher_name: 't1').should == 1 }
          specify { StudentsCount.calculate(year: 2012, account_name: 'history_account', teacher_name: 't2').should == 0 }
        end

        context "and :month option" do
          it "returns count at the last day of the month" do
            StudentsCount.calculate(year: 2012, month: 11, account_name: history_account.name).should == 3
          end
          context "and :teacher_name" do
            specify { StudentsCount.calculate(year: 2012, month: 9, account_name: 'history_account', teacher_name: 't2').should == 1 }
            specify { StudentsCount.calculate(year: 2012, month: 11, account_name: 'history_account', teacher_name: 't1').should == 2 }
          end
        end
      end
    end
    context "with :month option" do
      it "raises exception" do
        expect{ StudentsCount.calculate month: 1 }.to raise_exception
      end
    end
  end

  describe "test_helper" do
    it "should create contacts" do
      expect{ quick_create(3, 'students') }.to change{ Contact.count }.by 3
    end
  end

  # Creates :x, :status, in options[:in_account] with options[:with_teacher] as teacher
  #
  # @param x [Integer] default 1
  # @param status [String] default student
  # @param options [Hash]
  # @option options in_account [Account] default: new account
  # @option options with_teacher [String] teacher username. default: nil
  # @option options st_until [date] date until wich it was status
  # @option options tch_until [date] date until wich it had teacher_name
  def quick_create(x=1, status='student', options={})

    status = status.singularize.to_sym

    account = options[:in_account] || Account.make
    teacher = options[:with_teacher]


    x.times do
      c = Contact.make
      c.local_unique_attributes << LocalStatus.new(value: status, account: account)
      if teacher
        c.local_unique_attributes << LocalTeacher.new(value: teacher, account: account)
      end

      if options[:st_until]
        c.history_entries.create(attribute: "local_status_for_#{account.name}",
                                 old_value: options[:old_st],
                                 changed_at: options[:st_until].to_time)
      end
      if options[:tch_until]
        if options[:old_tch]
          c.history_entries.create(attribute: "local_teacher_for_#{account.name}",
                                   old_value: options[:old_tch],
                                   changed_at: options[:tch_until].to_time)
        else
          raise 'missing teacher'
        end
      end

      c.save!
    end

  end

end