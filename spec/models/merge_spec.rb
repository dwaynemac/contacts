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
      @gohan.save
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
end

