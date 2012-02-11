# encoding: UTF-8
require 'spec_helper'

describe Contact do

  it { should belong_to_related :owner }

  it { should reference_and_be_referenced_in_many :lists }

  it { should have_fields :first_name, :last_name, :gender }
  it { should have_fields :normalized_first_name, :normalized_last_name }
  it { should have_field(:status).of_type(Symbol)}
  it { should have_field(:level).of_type(String)}

  it { should validate_presence_of :first_name }

  it { should embed_many :contact_attributes }

  it { should embed_many :local_statuses }

  %W(first_name last_name).each do |attr|
    specify "normalized_#{attr} should be updated when #{attr} is updated" do
      @contact = Contact.make
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

  describe "#api_where" do
    context "{:email => 'dwa', :first_name => 'Ale'}" do
      let(:selector){{:email => "dwa", :first_name => "Ale"}}
      it "should be analog to .where(contact_attributes: { '$elemMatch' => { '_type' => 'Email', 'value' => /dwa/}}).where('first_name' => /Ale/)" do
        Contact.api_where(selector).selector.should == {
          :first_name =>/Ale/i,
          :contact_attributes=>{"$elemMatch"=>{"_type"=>"Email", "value"=>/dwa/i}}
        }
      end
    end
    context "email: 'dwa', telephone: '1234'" do
      let(:sel){{email: 'dwa', telephone: '1234'}}
      it "should build an $and" do
        Contact.api_where(sel).selector.should == {'$and' => [{:contact_attributes => {'$elemMatch' => {'_type' => 'Email','value' => /dwa/i}}},
                                                              {:contact_attributes => {'$elemMatch' => {'_type' => 'Telephone','value' => /1234/i}}}
                                                             ]}
      end
    end
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

  describe "#mobiles" do
    before do
      @con = Contact.make_unsaved
      @con.contact_attributes << Telephone.make(category: 'Mobile')
      @con.contact_attributes << Telephone.make(category: 'Mobile')
      @con.contact_attributes << Telephone.make(category: 'Home')
      @con.contact_attributes << Email.make
      @con.save!
    end
    it "should return all mobiles" do
      @con.mobiles.count.should == 2
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

  describe "#local_xxx_for_yyy" do
    before do
      class Xxx < LocalUniqueAttribute; end
      @contact = Contact.make
    end

    it "should return local_xxx for account named yyy" do
      c = @contact
      a = Account.make(name: 'yyy')
      lua = LocalUniqueAttribute.new(account: a, value: 'thevalue')
      lua._type = 'Xxx'
      c.contact_attributes << lua
      c.save!
      c.reload
      c.local_xxx_for_yyy.should == 'thevalue'
    end

    it "should create local_xxx for that account if non-existant" do
      x = @contact.contact_attributes.count
      account = Account.make(name: 'accname')
      @contact.local_xxx_for_accname=('new value')
      @contact.save! && @contact.reload
      @contact.local_unique_attributes.where('_type' => 'Xxx', account_id: account.id).first.try(:value).should == 'new value'
      @contact.local_unique_attributes.count.should == x+1
    end

    it "should change local_xxx for that accounts if it exists" do
      account = Account.make(name: 'accname')
      @contact.local_xxx_for_accname=('new value')
      @contact.save! && @contact.reload
      @contact.local_unique_attributes.where('_type' => 'Xxx', account_id: account.id).first.try(:value).should == 'new value'
      x = @contact.local_unique_attributes.count
      @contact.local_xxx_for_accname=('new value 2')
      @contact.save! && @contact.reload
      @contact.local_unique_attributes.where('_type' => 'Xxx', account_id: account.id).first.try(:value).should == 'new value 2'
      @contact.local_unique_attributes.count.should == x
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
    describe "when Homer Simpson exists" do
      before do
        contact = Contact.make(first_name: "Homer", last_name: "Simpson")
      end

      describe "a new contact named Marge Simpson" do
        before do
          @contact = Contact.new(first_name: "Marge", last_name: "Simpson")
        end

        it "should not have possible duplicates" do
          @contact.similar.should be_empty
        end
      end

      describe "a new contact with same last name and a more complete first name" do
        before do
          @contact = Contact.new(first_name: "Homer Jay", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }
      end

      describe "matching should not be case sensitive" do
        before do
          @contact = Contact.new(first_name: "hoMer Jay", last_name: "simPson")
        end

        it { @contact.similar.should_not be_empty }
      end

      describe "matching should ignore special characters" do
        before do
          @contact = Contact.new(first_name: "hôMer Jáy", last_name: "simPsōn")
        end

        it { @contact.similar.should_not be_empty }
      end

      describe "a new contact with same last name and first name" do
        before do
          @contact = Contact.new(first_name: "Homer", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.similar.should_not include(@contact) }
      end

      describe "an existing contact with same last name and first name" do
        before do
          @contact = Contact.make(first_name: "Homer", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.similar.should_not include(@contact) }
      end
    end

    describe "when Homer Jay Simpson exists" do
      before do
        contact = Contact.make(first_name: "Homer Jay", last_name: "Simpson")
      end

      describe "a new contact with same last name and only the first name" do
        before do
          @contact = Contact.new(first_name: "Homer", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }
      end

      describe "a new contact with same last name and only the last name" do
        before do
          @contact = Contact.new(first_name: "Jay", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.similar.should_not include(@contact) }
      end

      describe "a new contact with same last name and first name" do
        before do
          @contact = Contact.new(first_name: "Homer Jay", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.similar.should_not include(@contact) }
      end
    end

    describe "when homer@simpson.com is registered" do
      before do
        @homer = Contact.make(first_name: 'luis', last_name: 'lopez')
        @homer.contact_attributes << Email.make(value: 'homer@simpson.com')
        @homer.save!
      end
      it "new contact should match it by mail" do
        c = Contact.new(first_name: 'Santiago', last_name: 'Santo')
        c.contact_attributes << Email.make(value: 'homer@simpson.com')
        c.similar.should include(@homer)
      end
    end

    describe "when mobile 1540995071 is registered" do
      before do
        @homer = Contact.make_unsaved(first_name: 'Homero', last_name: 'Simpsonsizado')
        @homer.contact_attributes << Telephone.make(value: '1540995071', category: 'Mobile')
        @homer.save!
      end
      it "new contact should match it by mobile" do
        c = Contact.new(first_name: 'Juan', last_name: 'Perez')
        c.contact_attributes << Telephone.make(value: '1540995071', category: 'Mobile')
        c.similar.should include(@homer)
      end
      it "new contact should not match if mobile differs" do
        c = Contact.new(first_name: 'Bob', last_name: 'Doe')
        c.contact_attributes << Telephone.make(value: '15443340995071', category: 'Mobile')
        c.similar.should_not include(@homer)
      end
    end
  end

  describe "flagged to check for duplicates" do
    before do
      Contact.make(first_name: "dwayne", last_name: "mac")
      @contact = Contact.new(first_name: "dwayne", last_name: "mac", :check_duplicates => true)
    end

    it { @contact.should_not be_valid }
    describe "when validation is run" do
      before { @contact.valid? }

      it { @contact.errors[:possible_duplicates].should_not be_empty }
    end
  end

  describe "#unlink" do
    let(:contact){Contact.make}
    let(:account){Account.make}
    before do
      account.base_list.contacts << contact
    end
    it "should remove contact from all account's lists" do
      contact.unlink(account)
      contact.lists.should_not include(account.base_list)
    end

    context "if account is owner" do
      before do
        @account = Account.make
        @contact = Contact.make owner: @account
      end
      it "should remove ownership" do
        @contact.unlink(@account)
        @contact.owner.should be_nil
      end
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

  describe "#deep_error_messages" do
    before do
      @contact = Contact.make
    end
    context "if base has errors" do
      before do
        @contact.first_name = nil
      end
      it "they should be included" do
        @contact.should_not be_valid
        @contact.deep_error_messages.keys.should include(:first_name)
      end
    end
    context "if an email has invalid format" do
      before do
        @contact.contact_attributes << Email.make(value: 'invalid-mail')
      end
      it "it should show 'Email xxx is invalid'" do
        @contact.should_not be_valid
        @contact.deep_error_messages.should include(contact_attributes: [["invalid-mail is invalid"]])
      end
    end
    context "if an email is not unique" do
      before do
        c = Contact.make
        c.contact_attributes << Email.make(value: 'this@mail.com')
        c.save!
        @contact.contact_attributes << Email.make(value: 'this@mail.com')
      end
      it "it should show 'Email xxx is not unique'" do
        @contact.should_not be_valid
        @contact.deep_error_messages.should include(contact_attributes: [["this@mail.com is not unique"]])
      end
    end
  end

  describe "History" do
    let(:contact) { Contact.make(level: Contact::VALID_LEVELS[2], status: :student) }
    it "should record level changes" do
      expect{contact.update_attribute(:level, Contact::VALID_LEVELS[3])}.to change{contact.history_entries.count}
      contact.history_entries.last.old_value.should == Contact::VALID_LEVELS[2]
      contact.history_entries.last.changed_at.should be_within(1.second).of(Time.now)
    end
    it "should record status changes" do
      expect{ contact.update_attribute(:status, :former_student) }.to change{contact.history_entries.count}.by(1)
      contact.history_entries.last.old_value.should == :student
      contact.history_entries.last.changed_at.should be_within(1.second).of(Time.now)
    end
    it "should record local_status changes" do
      account = Account.make

      # tal vez esto puede ser un HistoryEntry de LocalStatus, no de Contact.
      # y contact.history_entries debería incluir los "hijos"

      x = contact.history_entries.count
      global_x = HistoryEntry.count


      contact.local_status={account_id: account.id, status: :prospect}
      contact.save
      contact.reload
      contact.history_entries.count.should == x+2 # .local_status(:nil -> :prospect)
      HistoryEntry.count.should == global_x+2

      y = contact.history_entries.count
      global_y = HistoryEntry.count

      # updating embedded local_status wont trigger local_status after_save
      contact.local_status=({account_id: account.id, status: :former_student})
      contact.save
      contact.reload
      contact.history_entries.count.should == y+2 # .status(:student -> :former_student) and .local_status(:prospect -> :former_student)
      HistoryEntry.count.should == global_y+2
    end
  end

  describe "owner auto assignment" do
    before do
      @account = Account.make
      @contact = Contact.create(Contact.plan(:owner => @account, :contact_attributes => [ContactAttribute.plan()]))
      @contact.lists = []
      @contact.save
    end

    it "on save a contact without status should set the owners main list" do
      @contact.lists.first.should == @account.base_list
    end

    example "if contact is a student, account where it is student should own it" do
      new_acc = Account.make
      @contact.local_status={account_id: new_acc.id, status: :student}
      @contact.save
      @contact.reload
      @contact.status.should == :student
      @contact.owner.should == new_acc
    end

  end

end
