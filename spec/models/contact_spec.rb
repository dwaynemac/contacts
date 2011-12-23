require 'spec_helper'

describe Contact do
  it { should embed_many :contact_attributes }

  it { should belong_to_related :owner }

  it { should reference_and_be_referenced_in_many :lists }

  it { should have_fields :first_name, :last_name }

  it { should validate_presence_of :first_name }

  it { should embed_many :local_statuses }

  it { should have_field(:status).of_type(Symbol)}
  it { should have_field(:level).of_type(String)}

  %W(student former_student prospect).each do |v|
    it { should allow_value(v).for(:status)}
  end

  %W(asdf asdf alumno ex-alumno).each do |v|
    it { should_not allow_value(v).for(:status)}
  end

  describe "#as_json" do
    before do
      @contact= Contact.make(:owner => Account.make)
    end
    it "should not include owner_id" do
      @contact.as_json.should_not have_key 'owner_id'
    end
    it "should inclue owner_name" do
      @contact.as_json.should have_key 'owner_name'
    end
  end

  describe "update_status!" do
    it "should be :student if there is any local_status :student" do
      ls = LocalStatus.make(status: :student)
      ls2 = LocalStatus.make(status: :prospect)
      c = Contact.make
      c.local_statuses << ls
      c.local_statuses << ls2
      c.update_status!
      c.status.should == :student
    end
    it "should be :former_student if there is any local_status :former_student and no :student" do
      c = Contact.make(local_statuses: [LocalStatus.make(status: :former_student),LocalStatus.make(status: :prospect)])
      c.status.should == :former_student
    end
    it "should be :prospect if there is any local_status :prospect and no :student or :former_student" do
      c = Contact.make(local_statuses: [LocalStatus.make(status: :prospect)])
      c.status.should == :prospect
    end
  end

  describe "local_status=(account_id,new_status)" do
    before do
      @contact = Contact.make
      @account = Account.make
      @contact.local_statuses << LocalStatus.make
      @contact.local_statuses << LocalStatus.make(account: @account)
    end
    it "should create local_status for that account if non-existant" do
      @contact.local_statuses.count.should == 2
      account = Account.make
      @contact.local_status=({account_id: account.id, status: :student})
      @contact.save && @contact.reload
      @contact.local_statuses.where(account_id: account.id).first.status.should == :student
      @contact.local_statuses.count.should == 3
    end
    it "should change local_status for that accounts if it exists" do
      @contact.local_status=({account_id: @account.id,status: :student})
      @contact.save && @contact.reload
      @contact.local_statuses.where(account_id: @account.id).first.status.should == :student
    end
    it "should not delete other local_statuses" do
      @contact.local_status=({account_id: @account.id,status: :former_student})
      expect{@contact.save}.not_to change{@contact.local_statuses.count}
    end
    it "should fail silently if called with a non-hash argument" do
      @contact.local_status=(:prospect)
      expect{@contact.save}.not_to raise_error
    end
  end

  describe "when scoped to a list" do
    before do
      @account = Account.make
      @contact = @account.lists.first.contacts.create(:first_name => "Marge")
    end

    it "should set the owner" do
      @contact.owner.should == @account
    end

    it "should update the lists contacts" do
      @account.lists.first.contacts.should include(@contact)
    end

    describe "and after adding the contact to a new list" do
      before do
        @account_b = Account.make(:lists => [List.make])
        @contact.lists << @account_b.lists.first
      end

      specify { @contact.lists.count.should == 2 }

      it "should not update the owner" do
        @contact.owner.should == @account
      end
    end
  end

  describe "#create with nested attribute params" do
    before do
      @account = Account.make
      @contact = Contact.create(Contact.plan(:owner => @account, :contact_attributes => [ContactAttribute.plan(:account => nil)]))
    end

    it "should set the owner on new attributes" do
      @contact.contact_attributes.first.account.should == @account
    end
  end

  describe "#save" do
    before do
      @account = Account.make
      @contact = Contact.create(Contact.plan(:owner => @account, :contact_attributes => [ContactAttribute.plan()]))
      @contact.lists = []
      @contact.save
    end

    it "should set the owners main list" do
      @contact.lists.first.should == @account.lists.first
    end
  end

  describe "#save with nested attribute params" do
      before do
        @account = Account.make
        @contact = Contact.create(Contact.plan(:owner => @account))
        @contact.update_attributes(:contact_attributes => [ContactAttribute.plan(:account => nil)])
      end

      it "should set the owner on new attributes" do
        @contact.contact_attributes.first.account.should == @account
      end
  end

  describe "mongoid_search" do
    before do
      account = Account.make

      @first_name = Contact.make(first_name: "dwayne")
      @first_name.contact_attributes << Telephone.new(account_id: account._id, value: "1234")
      @first_name.save

      @email = Contact.make(last_name: "mac")
      @email.contact_attributes << Email.new(account_id: account._id, value: "dwaynemac@gmail.com")
      @email.save

      @last_name = Contact.make(first_name: "asdf", last_name: "dwayne")
    end
    it "should find by email" do
      Contact.csearch("dwaynemac@gmail.com").should include(@email)
    end
  end

  describe "#similar" do
    before do
      contact = Contact.make(first_name: "dwayne", last_name: "mac")
    end

    describe "new contact with same last name" do
      before do
        @contact = Contact.new(first_name: "Diego", last_name: "mac")
      end

      it { @contact.similar.should_not be_empty }
    end

    describe "existing contact with same last name" do
      before do
        @contact = Contact.make(first_name: "Diego", last_name: "mac")
      end

      it { @contact.similar.should_not be_empty }

      it { @contact.similar.should_not include(@contact) }
    end
  end

  describe "flagged to check for duplicates" do
    before do
      Contact.make(first_name: "dwayne", last_name: "mac")
      @contact = Contact.new(first_name: "Diego", last_name: "mac", :check_duplicates => true)
    end

    it { @contact.should_not be_valid }
    describe "when validation is run" do
      before { @contact.valid? }

      it { @contact.possible_duplicates.should_not be_empty }
    end
  end

  describe "#owner_name" do
    before do
      @account = Account.make
      @contact = Contact.make(:owner => @account)
    end
    it "should return owner account name" do
      @contact.owner_name.should == @account.name
    end
    it "should set owner account by name" do
      new_account = Account.make
      @contact.owner_name = new_account.name
      @contact.save
      @contact = Contact.find(@contact.id)
      @contact.owner_name.should == new_account.name
    end
  end
end
