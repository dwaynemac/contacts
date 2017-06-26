# encoding: UTF-8
require 'ar_spec_helper'

describe NewContact do

  it { should have_many(:accounts).through(:account_contacts) }

  it { should have_many(:contact_attributes) }
  
  it { should belong_to :owner }

  it { should respond_to(:first_name, :last_name, :status, :gender, :level, :in_professional_training, :first_enrolled_on, :occupations) }

  it { should respond_to :local_statuses }
  it { should respond_to :local_teachers }
  
  it { should validate_presence_of :first_name }

  describe "capitalizes first word of first and last name" do
    it "only capitalizes first word" do
      c = NewContact.new(first_name: 'alejandro diego', last_name: 'mac gowan')
      c.save
      expect(c.first_name).to eq 'Alejandro diego'
      expect(c.last_name).to eq 'Mac gowan'
    end
    it "wont change caps on second words of name and last name" do
      c = NewContact.new(first_name: 'Alejandro Diego', last_name: 'Mac Gowan')
      c.save
      expect(c.first_name).to eq 'Alejandro Diego'
      expect(c.last_name).to eq 'Mac Gowan'
    end
    it "wont raise exception with empty strings" do
      c = NewContact.new(first_name: 'Alejandro Diego', last_name: '')
      expect{c.save}.not_to raise_exception
      expect(c.first_name).to eq 'Alejandro Diego'
      expect(c.last_name).to eq ''
    end
  end

  describe "#derose_id" do
    it { should respond_to :derose_id }
    it { should validate_uniqueness_of(:derose_id).allow_blank }
  end

  describe "#kshema_id" do
    it { should respond_to :kshema_id }
    it { should validate_uniqueness_of(:kshema_id).allow_nil }
  end

  describe "#birthday" do
    it "returns contact's birthday" do
      c = NewContact.make
      da = NewDateAttribute.new(category: 'birthday', year: 1983, month: 12, day: 1)
      c.contact_attributes << da
      c.save!
      c.reload.date_attributes.count.should == 1
      c.birthday.should == da
    end
  end

  describe "owner auto assignment" do
    let(:account){ NewAccount.make }
    let(:contact){NewContact.create(NewContact.plan(owner: account))}

    context "if contact has no status" do
      it "should be linked to account" do
        contact.save
        contact.reload
        expect(account).to be_in contact.accounts
      end
    end

    context "if contact is a student" do
      let!(:new_account){ NewAccount.make }
      before do
        expect do
          contact.send("local_status_for_" + new_account.name + "=", :student)
          contact.save
          contact.reload
        end.to change{contact.status}.to :student
      end
      example "account where it is student should own it" do
        expect(contact.owner).to eq new_account
      end
      it "should be linked to the owner" do
        expect(contact.accounts).to include new_account
      end
    end
  end

  context "- merges -" do
    let(:contact){NewContact.make(first_name: 'fn', last_name: 'ln')}
    let(:second_contact){NewContact.make(first_name: 'fn', last_name: 'ln')}
    let(:merge){ NewMerge.make(first_contact_id: contact.id, second_contact_id: second_contact.id) }

    describe "#active_merges" do
      subject { contact.active_merges }
      context "when contact is not in a merge" do
        it { should be_empty }
      end
      context "when contact is in a merge" do
        context "with state :merged" do
          before { merge.update_attribute :state, :merged }
          it { should be_empty }
        end
        %W(ready merging pending).each do |state|
          context "with state #{state}" do
            before { merge.update_attribute :state, state }
            it { should_not be_empty }
          end
        end
      end
    end

    describe "#in_active_merge?" do
      subject { contact }
      context "when contact is not in a merge" do
        it { should_not be_in_active_merge }
      end
      context "when contact is in a merge" do
        context "with state :merged" do
          before { merge.update_attribute :state, :merged }
          it { should_not be_in_active_merge }
        end
        %W(ready merging pending).each do |state|
          context "with state #{state}" do
            before { merge.update_attribute :state, state }
            it { should be_in_active_merge }
          end
        end
      end
    end
  end

  %W(first_name last_name).each do |attr|
    specify "normalized_#{attr} should be updated when #{attr} is updated" do
      @contact = NewContact.make
      @contact.send("normalized_#{attr}").should_not be_nil

      @contact.send("#{attr}=","áéíóū")
      @contact.save
      @contact.send("normalized_#{attr}").should == "aeiou"
    end
  end

  %W(student former_student prospect).each do |v|
    it { should allow_value(v).for(:status)}
  end

  %W(asdf asdf alumno ex-alumno).each do |v|
    it { should_not allow_value(v).for(:status)}
  end

  describe "has a global teacher" do
    it { should respond_to(:global_teacher_username) }
    # it should keep track of changes to global teacher --> see spec below: "Contact History should record teacher changes"
    it "should automatically set global_teacher_username as local_teacher_username in account where it is owned" do
      account = NewAccount.make
      c = NewContact.make(global_teacher_username: 'dwayne.macgowan', owner_id: account.id)
      ac = c.account_contacts.find_by_account_id(account.id)
      ac.local_teacher_username =  'new.teacher'
      ac.save
      c.save
      c.reload
      c.global_teacher_username.should == 'new.teacher'
    end
  end  
end
