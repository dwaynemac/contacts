require File.dirname(__FILE__) + '/../spec_helper'

describe Merge do

  it { should validate_presence_of :first_contact_id }
  it { should validate_presence_of :second_contact_id }

  describe "Creation" do
    before do
      @goku1 = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante")
      @goku1.save

      @goku2 = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante")
      @goku2.save

      @gohan = Contact.make(:first_name => "Son", :last_name => "Gohan", :level => "aspirante")
      @gohan.contact_attributes << Identification.new(:category => :dni, :value => "2222222")
      @gohan.save

      @gohan2 = Contact.make(:first_name => "Son", :last_name => "Gohan", :level => "aspirante")
      @gohan2.contact_attributes << Identification.new(:category => :dni, :value => "11111111")
      @gohan2.save
    end

    it "should check for contacts existence" do
      m = Merge.new(:first_contact_id => "fake_id", :second_contact_id => @goku2.id)
      m.save.should == false
      m = Merge.new(:first_contact_id => @goku1.id, :second_contact_id => @goku2.id)
      m.save.should == true
    end

    it "should check for similarity of contacts" do
      m = Merge.new(:first_contact_id => @goku1.id, :second_contact_id => @gohan.id)
      m.save.should == false
      m = Merge.new(:first_contact_id => @gohan.id, :second_contact_id => @gohan2.id)
      m.save.should == false
    end

    it "should be in not_started state" do
      m = Merge.new(:first_contact_id => @goku1.id, :second_contact_id => @goku2.id)
      m.should be_embryonic # RSpec magic for: m.embryonic?.should == true
    end

    describe "Father Choosing" do

      before do
        @student_goku = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :student, :level => "aspirante")
        @student_goku.save

        @pr_goku_2a = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect, :level => "aspirante")
        @pr_goku_2a.contact_attributes << Telephone.make(:value => "5445234342")
        @pr_goku_2a.contact_attributes << Email.make(:value => "goku_two@email.com")
        @pr_goku_2a.save

        @pr_goku_1a = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect, :level => "aspirante")
        @pr_goku_1a.contact_attributes << Email.make(value: 'goku_one@email.com')
        @pr_goku_1a.save

        @new_pr_goku_1a = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect, :level => "aspirante")
        @new_pr_goku_1a.contact_attributes << Email.make(value: 'goku_one_but_new@email.com')
        @new_pr_goku_1a.save

      end

      it "should choose depending on status hierarchy (first criteria) - between prospect and student, student if chosen" do
        m = Merge.new(:first_contact_id => @student_goku.id, :second_contact_id => @pr_goku_2a.id)
        m.save
        m.father_id.should == @student_goku.id
      end

      it "should choose depending on amount of contact attributes if they share status (second criteria)" do
        m = Merge.new(:first_contact_id => @pr_goku_1a.id, :second_contact_id => @pr_goku_2a.id)
        m.save
        m.father_id.should == @pr_goku_2a.id
      end

      it "should choose depending on updated time if they share the amount of contact attributes (third criteria)" do
        m = Merge.new(
          :first_contact_id => @pr_goku_1a.id,
          :second_contact_id => @new_pr_goku_1a.id
        )
        m.save
        m.father_id.should == @new_pr_goku_1a.id
      end

    end

    describe "Look for Warnings" do

      it "should initialize Merge in pending_confirmation state when there are one or more warnings" do

        account_1 = Account.make
        account_2 = Account.make

        @father = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante")
        @father.local_unique_attributes << LocalStatus.make(:value => :student, :account => account_1)
        @father.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => account_2)
        @father.save

        @son = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "maestro")
        @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_1)
        @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_2)
        @son.save

        m = Merge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
        m.save

        m.should be_pending_confirmation
        m.warnings.size.should > 0
        m.warnings['local_statuses'].size == 1
        m.warnings['local_statuses'].first == account_2.id

        m.warnings['level'].should == true
      end
    end
  end

  describe "Merging" do

    before do

      @account_1 = Account.make
      @account_2 = Account.make
      @account_3 = Account.make

      @contact_attributes = {
        'father_telephone' => Telephone.make(:value => '111111111'),
        'father_email' => Email.make(:value => 'father@mail.com'),
        'son_telephone' => Telephone.make(:value => '555555555'),
        'son_email' => Email.make(:value => 'son@mail.com')
      }

      @father_list = List.make
      @son_list = List.make

      #Father
      @father = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante", :lists => [@father_list])

      @father.local_unique_attributes << LocalStatus.make(:value => :student, :account => @account_1)
      @father.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => @account_2)

      @father.local_unique_attributes << LocalTeacher.make(:value => 'Roshi', :account => @account_1)

      @father.contact_attributes << [@contact_attributes['father_telephone'], @contact_attributes['father_email']]

      @father.save

      #Son
      @son = Contact.make(:first_name => "Son", :last_name => "Goku2", :level => "maestro", :lists => [@son_list])

      @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => @account_1)
      @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => @account_2)
      @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => @account_3)

      @son.local_unique_attributes << LocalTeacher.make(:value => 'Kami', :account => @account_1)
      @son.local_unique_attributes << LocalTeacher.make(:value => 'Kaio', :account => @account_2)

      @son.contact_attributes << [@contact_attributes['son_telephone'], @contact_attributes['son_email']]

      @son.save

      # it should call ActivityStream API (expectation has to be befare call to @m.start)
      mock = ActivitiesMerge.new
      ActivitiesMerge.should_receive(:new).with(parent_id: @father.id.to_s, son_id: @son.id.to_s).and_return(mock)
      ActivitiesMerge.any_instance.should_receive(:create).and_return(true)

      @m = Merge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
      @m.save

      @m.should be_pending_confirmation
      @m.confirm
      @m.start

      @father.reload
    end

    it "should have all the contact attributes" do
      @contact_attributes.values.each do |cd|
        @father.contact_attributes.include?(cd).should == true
      end
    end

    it "should keep father's level" do
      @father.level.should == 'aspirante'
    end

    it "should keep one local status for each account keeping father's value in case of repetition" do
      @father.local_statuses.where(:account_id => @account_1.id).first.value.should == :student
      @father.local_statuses.where(:account_id => @account_2.id).first.value.should == :prospect
      @father.local_statuses.where(:account_id => @account_3.id).first.value.should == :former_student
    end

    it "should keep one local teacher for each account keeping father's teacher in case of repetition" do
      @father.local_teachers.where(:account_id => @account_1.id).first.value.should == 'Roshi'
      @father.local_teachers.where(:account_id => @account_2.id).first.value.should == 'Kaio'
    end

    it "should keep all the lists" do
      @father.lists.include?(@father_list).should == true
      @father.lists.include?(@son_list).should == true
    end

    it "should keep old names" do
      @father.contact_attributes.where(:name => "old_first_name").first.value.should == "Son"
      @father.contact_attributes.where(:name => "old_last_name").first.value.should == "Goku2"
    end

    it "should keep record of migrated services" do
      @m.services['activity_stream'].should be_true
    end
  end
end

