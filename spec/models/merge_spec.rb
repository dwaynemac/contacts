require File.dirname(__FILE__) + '/../spec_helper'

describe Merge do

  it { should validate_presence_of :first_contact_id }
  it { should validate_presence_of :second_contact_id }

  describe "Creation" do

    before do
      @goku1 = Contact.make(:first_name => "Son", :last_name => "Goku")
      @goku1.save

      @goku2 = Contact.make(:first_name => "Son", :last_name => "Goku")
      @goku2.save

      @gohan = Contact.make(:first_name => "Son", :last_name => "Gohan")
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
      m.not_started?.should == true
    end

    describe "Father Choosing" do

      before do
        @student_goku = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :student)
        @student_goku.save

        @pr_goku_2a = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect)
        @pr_goku_2a.contact_attributes << Telephone.make(:value => "5445234342")
        @pr_goku_2a.contact_attributes << Email.make(:value => "goku_two@email.com")
        @pr_goku_2a.save

        @pr_goku_1a = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect)
        @pr_goku_1a.contact_attributes << Email.make(value: 'goku_one@email.com')
        @pr_goku_1a.save

        @new_pr_goku_1a = Contact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect)
        @new_pr_goku_1a.contact_attributes << Email.make(value: 'goku_one_but_new@email.com')
        @new_pr_goku_1a.save

      end

      it "should choose depending on status hirarchy (first criteria)" do
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

  end
end

