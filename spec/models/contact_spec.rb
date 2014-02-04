# encoding: UTF-8
require 'spec_helper'

describe Contact do

  it { should belong_to_related :owner }

  it { should reference_and_be_referenced_in_many :lists }

  it { should have_fields :first_name, :last_name, :gender }
  it { should have_fields :normalized_first_name, :normalized_last_name }
  it { should have_field(:status).of_type(Symbol)}
  it { should have_field(:level).of_type(Integer)}

  describe "#kshema_id" do
    it { should have_field :kshema_id }
    it { should validate_uniqueness_of :kshema_id }
    it "allows blank" do
      Contact.make(kshema_id: nil)
      c = Contact.make_unsaved(kshema_id: nil)
      c.should be_valid
    end
  end

  describe "#birthday" do
    it "returns contact's birthday" do
      c = Contact.make
      da = DateAttribute.new(category: 'birthday', year: 1983, month: 12, day: 1)
      c.contact_attributes << da
      c.save!
      c.reload.date_attributes.count.should == 1
      c.birthday.should == da
    end
  end


  it { should validate_presence_of :first_name }

  it { should embed_many :contact_attributes }
  it { should embed_many :local_unique_attributes }

  it { should respond_to :local_statuses }
  it { should respond_to :local_teachers }


  context "- merges -" do
    let(:contact){Contact.make(first_name: 'fn', last_name: 'ln')}
    let(:merge){ Merge.make(first_contact: contact, second_contact: Contact.make(first_name: 'fn', last_name: 'ln')) }

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
        [:ready, :merging, :pending].each do |state|
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
        [:ready, :merging, :pending].each do |state|
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

  describe "has a global teacher" do
    it { should have_field(:global_teacher_username).of_type(String) }
    # it should keep track of changes to global teacher --> see spec below: "Contact History should record teacher changes"
    it "should automatically set global_teacher_username as local_teacher_username in account where it is owned" do
      account = Account.make
      c = Contact.make(global_teacher_username: 'dwayne.macgowan', owner: account)
      c.local_unique_attributes << LocalTeacher.make(account: account, value: 'new.teacher')
      c.save
      c.reload
      c.global_teacher_username.should == 'new.teacher'
    end
  end

  describe "#_keywords" do
    it "should be updated when contact is created" do
      c = Contact.make_unsaved(first_name: 'dwayne', last_name: 'macg')
      c.save
      c._keywords.should include('dwayne')
      c._keywords.should include('macg')
    end
    it "should be updated when a new attribute is added" do
      c = Contact.make
      c.contact_attributes << Email.make(value: 'dwaynemac@gmail.com')
      c.save
      c._keywords.should include('dwaynemac')
      c._keywords.should include('gmail')
    end
    it "should be updated when an attribute is deleted" do
      c = Contact.make
      c.contact_attributes << Email.make(value: 'dwaynemac@gmail.com')
      c.save
      c._keywords.should include('dwaynemac')
      c.contact_attributes.last.destroy
      c.save
      c._keywords.should_not include 'dwaynemac'
    end
    it "should be updates with the user tag" do
      a = Account.make
      c = Contact.make
      c.tags.create(account: a, name: "comple")
      c.save
      c._keywords.should include('comple')
    end
    it "should ignore words: com net org ar br pt" do
      c = Contact.make
      %w(com net org ar br pt).each do |k|
        c.contact_attributes << Email.make(value: "dwaynemac@gmail.#{k}")
        c.save
        c._keywords.should include('dwaynemac')
        c._keywords.should include('gmail')
        c._keywords.should_not include k
      end
    end
  end

  describe "#tag_ids_for_request_account" do
    before do
      @account = Account.make(name: "belgrano")
      @another_account = Account.make
      @contact = Contact.make(account_name: @account.name)
      @contact.tags.create(name: "first account", account_id: @account.id)
      @contact.tags.create(name: "second account", account_id: @another_account.id)
    end

    context "with request account" do
      before do
        @contact.request_account_name = @account.name
      end
      it "returns tag_ids of request account" do
        @contact.tag_ids_for_request_account.should == @contact.tags.where(account_id: @account.id).map(&:id)
      end
    end
    
    context "without request account" do
      it "returns nil" do
        @contact.tag_ids_for_request_account.should be_nil
      end
    end
  end

  describe "#tag_ids_for_request_account=" do
    before do
      @account = Account.make(name: "belgrano")
      @another_account = Account.make
      @contact = Contact.make(account_name: @account.name)
      @contact.tags.create(name: "first account", account_id: @account.id)
      @other_account_tag = @contact.tags.create(name: "second account", account_id: @another_account.id)
    end

    context "with request account" do
      before do
        @contact.request_account_name = @account.name
        @tag = Tag.create(name: "new tag", account_id: @account.id)
        @second_tag = Tag.create(name: "second tag", account_id: @account.id)
        @third_tag = Tag.create(name: "testtag", account_id: @account.id)
      end
      it "overriddes tags for request account" do
        @contact.tag_ids_for_request_account.should == @contact.tags.where(account_id: @account.id).map(&:id)
        @contact.tag_ids_for_request_account = [@tag.id, @second_tag.id]
        @contact.save
        @contact.reload.tag_ids_for_request_account.should == @contact.tags.where(account_id: @account.id).map(&:id)
        @contact.tag_ids_for_request_account.should include(@second_tag.id)
      end
      it "doesnt remove tags from other accounts" do
        @contact.tag_ids_for_request_account.should == @contact.tags.where(account_id: @account.id).map(&:id)
        @contact.tag_ids_for_request_account = [@tag.id, @second_tag.id]
        @contact.save
        @contact.reload.tags.where(account_id: @another_account.id).should == [@other_account_tag]
      end
      it "should add the tags to the keywords" do
        @contact.tag_ids_for_request_account.should == @contact.tags.where(account_id: @account.id).map(&:id)
        @contact.tag_ids_for_request_account = [@tag.id, @second_tag.id, @third_tag.id]
        @contact.save
        @contact.index_keywords!
        @contact.reload.tag_ids_for_request_account.should include(@third_tag.id)
        @contact.reload.tags.should include(@third_tag)
        @contact.reload._keywords.should include(@third_tag.name)
      end
      context "with it receives an empty string" do
        it "should leave an empty array" do
          @contact.tag_ids_for_request_account = ""
          @contact.save
          @contact.reload.tag_ids_for_request_account.should be_empty
        end
      end
    end
    
    context "without request account" do
      it "raises en exception" do
        expect{@contact.tag_ids_for_request_account=[54]}.to raise_exception
      end
    end
  end

  describe "#as_json" do
    before do
      @contact= Contact.make(:owner => Account.make)
      @contact.local_unique_attributes << LocalTeacher.make(account: Account.first)
    end
    it "should not include owner_id" do
      @contact.as_json({select: 'all'}).should_not have_key 'owner_id'
    end
    it "should inclue owner_name" do
      @contact.as_json({select: 'all'}).should have_key 'owner_name'
    end
    it "should include :coefficients_counts key" do
      @contact.as_json({select: 'all'}).should have_key 'coefficients_counts'
    end
    it "should include global_teacher_username" do
      @contact.as_json({select: 'all'}).should have_key 'global_teacher_username'
    end
    it "includes #in_active_merge" do
      @contact.as_json({select: 'all'}).should have_key 'in_active_merge'
    end
    context "account specified" do
      subject { @contact.as_json(account: Account.first, select: 'all')}
      it { should have_key 'coefficient'}
      it { should have_key 'local_teacher' }
    end
    context "account not specified" do
      subject { @contact.as_json(select: 'all')}
      it { should_not have_key 'coefficient' }
      it { should_not have_key 'local_teacher' }
    end
  end

  describe "#coefficients_counts" do
    it "should return all coeficients, even if zero" do
      subj = Contact.make.coefficients_counts
      Coefficient::VALID_VALUES.each do |vv|
        subj.should have_key(vv)
      end
    end
    it "should count coefficients grouping by value" do
      c = Contact.make
      3.times { c.local_unique_attributes << Coefficient.new(value: 'fp', account: Account.make) }
      2.times { c.local_unique_attributes << Coefficient.new(value: 'perfil', account: Account.make) }
      5.times { c.local_unique_attributes << Coefficient.new(value: 'pmas', account: Account.make) }

      c.coefficients_counts['fp'].should == 3
      c.coefficients_counts['pmenos'].should == 0
      c.coefficients_counts['perfil'].should == 2
      c.coefficients_counts['pmas'].should == 5
    end
  end

  describe "#mobiles" do
    before do
      @con = Contact.make_unsaved
      @con.contact_attributes << Telephone.make(category: 'mobile')
      @con.contact_attributes << Telephone.make(category: 'mobile')
      @con.contact_attributes << Telephone.make(category: 'home')
      @con.contact_attributes << Email.make
      @con.save!
    end
    it "should return all mobiles" do
      @con.mobiles.count.should == 2
    end
  end

  describe "update_status!" do
    it "should be :student if there is any local_status :student" do
      ls = LocalStatus.make(value: :student)
      ls2 = LocalStatus.make(value: :prospect)
      c = Contact.make
      c.local_unique_attributes << ls
      c.local_unique_attributes << ls2
      c.update_status!
      c.status.should == :student
    end
    it "should be :former_student if there is any local_status :former_student and no :student" do
      c = Contact.make(local_unique_attributes: [LocalStatus.make(value: :former_student),LocalStatus.make(value: :prospect)])
      c.status.should == :former_student
    end
    it "should be :prospect if there is any local_status :prospect and no :student or :former_student" do
      c = Contact.make(local_unique_attributes: [LocalStatus.make(value: :prospect)])
      c.status.should == :prospect
    end
  end

  describe "local_status=(account_id,new_status)" do
    before do
      @contact = Contact.make
      @account = Account.make
      @contact.local_unique_attributes << LocalStatus.make
      @contact.local_unique_attributes << LocalStatus.make(account: @account)
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

  describe "#xxx_for_yyy" do
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
      c.xxx_for_yyy.should == 'thevalue'
    end

    it "should create local_xxx for that account if non-existant" do
      x = @contact.contact_attributes.count
      account = Account.make(name: 'accname')
      @contact.xxx_for_accname=('new value')
      @contact.save! && @contact.reload
      @contact.local_unique_attributes.where('_type' => 'Xxx', account_id: account.id).first.try(:value).should == 'new value'
      @contact.local_unique_attributes.count.should == x+1
    end

    it "should change local_xxx for that accounts if it exists" do
      account = Account.make(name: 'accname')
      @contact.xxx_for_accname=('new value')
      @contact.save! && @contact.reload
      @contact.local_unique_attributes.where('_type' => 'Xxx', account_id: account.id).first.try(:value).should == 'new value'
      x = @contact.local_unique_attributes.count
      @contact.xxx_for_accname=('new value 2')
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
      @contact.in?(@account.lists.first.contacts).should be_true
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
    describe "Email search" do
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

    describe "must match all words," do
      before do
        account = Account.make

        @goku_contact = Contact.make(first_name: "Son", last_name: "Goku")
        @gohan_contact = Contact.make(first_name: "Son", last_name: "Gohan")
      end
      it "should find only Goku" do
        Contact.csearch("Son Gok").should include(@goku_contact)
        Contact.csearch("Son Gok").should_not include(@gohan_contact)
      end
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

      describe "a new contact named Marge" do
        let(:contact){ Contact.new(first_name: 'Marge')}
        it "should not have possible duplicates" do
          contact.similar.should be_empty
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

        it { @contact.in?(@contact.similar).should_not be_true }
      end

      describe "an existing contact with same last name and first name" do
        before do
          @contact = Contact.make(first_name: "Homer", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contacts.in?(@contact.similar).should_not be_true }
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

        it { @contact.in?(@contact.similar).should_not be_true }
      end

      describe "a new contact with same last name and first name" do
        before do
          @contact = Contact.new(first_name: "Homer Jay", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.in?(@contact.similar).should_not be_true }
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
        @homer.in?(c.similar).should be_true
      end
    end

    describe "when mobile 1540995071 is registered" do
      before do
        @homer = Contact.make_unsaved(first_name: 'Homero', last_name: 'Simpsonsizado')
        @homer.contact_attributes << Telephone.make(value: '1540995071', category: 'mobile')
        @homer.save!
      end
      it "new contact should match it by mobile" do
        c = Contact.new(first_name: 'Juan', last_name: 'Perez')
        c.contact_attributes << Telephone.make(value: '1540995071', category: 'mobile')
        @homer.in?(c.similar).should be_true
      end
      it "new contact should not match if mobile differs" do
        c = Contact.new(first_name: 'Bob', last_name: 'Doe')
        c.contact_attributes << Telephone.make(value: '15443340995071', category: 'mobile')
        @homer.in?(c.similar).should_not be_true
      end
    end

    describe "when DNI 30366832 is registered" do
      before do
        @similar = Contact.make(first_name: 'Dwayne', last_name: 'Macgowan')
        @similar.contact_attributes << Identification.make_unsaved(value: '30366832', category: 'DNI')
        @similar.save!
      end
      describe "a new contact" do
        before do
          @new_contact = Contact.make_unsaved(first_name: 'Alejandro', last_name: 'Mac Gowan')
        end
        describe "with DNI 30366832" do
          before do
            @new_contact.contact_attributes << Identification.make_unsaved(value: '30366832', category: 'DNI')
          end
          it "should have possible duplicates" do
            @similar.in?(@new_contact.similar).should be_true
          end
        end
        describe "with DNI 3/0.3_6 6.83-2" do
          before do
            @new_contact.contact_attributes << Identification.make_unsaved(value: '3/0.3_6 6.83-2', category: 'DNI')
          end
          it "should have possible duplicates" do
            @similar.in?(@new_contact.similar).should be_true
          end
        end
        describe "with CPF 30366832" do
          before do
            @new_contact.contact_attributes << Identification.make_unsaved(value: '30366832', category: 'CPF')
          end
          it "should not have possible duplicates" do
            @new_contact.similar.should be_empty
          end
        end
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

    it "removes all account's lists from contact" do
      contact.unlink(account)
      account.base_list.in?(contact.reload.lists).should be_false
      #contact.reload.lists.should_not include(account.base_list)
    end

    context "if account is owner" do
      before do
        @account = Account.make
        @contact = Contact.make owner: @account
      end
      it "removes ownership" do
        @contact.unlink(@account)
        @contact.reload.owner.should be_nil
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
        @contact.deep_error_messages.should include(contact_attributes: [["invalid-mail bad email format"]])
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

  it "creates an activity when level changes" do
    c = Contact.make(status: 'student')
    c.level = 'sádhaka'
    ActivityStream::Activity.any_instance.should_receive(:create)
    c.save
  end


  describe "History" do
    let(:contact) { Contact.make(level: "yôgin", status: :student) }

    it "should record global teacher changes" do
      expect{contact.update_attribute(:global_teacher_username,'dwayne.macgowan')}.to change{contact.history_entries.count}
      contact.history_entries.last.old_value.should be_nil
      contact.history_entries.last.changed_at.should be_within(1.second).of(Time.now)
      contact.update_attribute(:global_teacher_username,'luis.perichon')
      contact.history_entries.last.old_value.should =='dwayne.macgowan'
    end

    it "should record level changes" do
      expect{contact.update_attribute(:level, "chêla")}.to change{contact.history_entries.count}
      contact.history_entries.last.old_value.should == Contact::VALID_LEVELS["yôgin"]
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

    context "when :skip_history_entries is true" do
      it "doesnt record changes" do
        contact.skip_history_entries = true
        expect{contact.update_attribute(:global_teacher_username,'dwayne.macgowan')}.not_to change{contact.history_entries.count}
      end

      it "doesnt record local_status changes" do
        account = Account.make

        x = contact.history_entries.count
        global_x = HistoryEntry.count

        contact.local_status={account_id: account.id, status: :prospect}
        contact.skip_history_entries = true
        expect{contact.save}.not_to change{HistoryEntry.count}

        # updating embedded local_status wont trigger local_status after_save
        contact.local_status=({account_id: account.id, status: :former_student})
        expect{contact.save}.not_to change{HistoryEntry.count}
      end
    end
  end

  describe "#linked_accounts" do
    let(:account){Account.make}
    let(:contact){Contact.make(owner: account)}
    it "lists accounts linked with contact" do
      contact.linked_accounts.should include account
    end
  end

  describe "owner auto assignment" do
    before do
      @account = Account.make
      @contact = Contact.create(Contact.plan(:owner => @account, :contact_attributes => [ContactAttribute.plan()]))
      @contact.lists = []
      @contact.save
    end

    context "if contact has no status" do

      it "on save a contact without status should set the owners main list" do
        @contact.lists.first.should == @account.base_list
      end
    end

    context "if contact is a student" do
      before do
        @new_acc = Account.make
        @contact.local_status={account_id: @new_acc.id, status: :student}
        @contact.save
        @contact.reload
        @contact.status.should == :student
      end
      example "account where it is student should own it" do
        @contact.owner.should == @new_acc
      end
    end
  end

  # real life example
  describe ".with_attribute_value_at" do
    describe "with local_unique_attributes" do
      before do
        a = Account.make(name: 'martinez')
        @contact = Contact.make
        @contact.local_unique_attributes << LocalStatus.make(value: :student, account: a)
        @contact.save
        @contact.reload.history_entries.delete_all
        @contact.local_status_for_martinez.should == :student

        HistoryEntry.create(attribute: 'local_status_for_martinez',
                            old_value: '',
                            changed_at: DateTime.civil(2012,11,21,20,34,39).to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
        HistoryEntry.create(attribute: 'local_status_for_martinez',
                            old_value: :prospect,
                            changed_at: DateTime.civil(2012,11,21,20,35,50).to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
      end
      example { contacts_with_value_at('student',Date.civil(2012,11,20)).should_not include @contact}
      example { contacts_with_value_at('student',Date.civil(2012,11,22)).should include @contact}
      example { contacts_with_value_at('prospect',DateTime.civil(2012,11,21,20,34,41).to_time).should include @contact }
      # helper
      def contacts_with_value_at(value,time)
        Contact.with_attribute_value_at('local_status_for_martinez',value,time)
      end
    end
    describe "with level" do
      before do
        @contact = Contact.make
        HistoryEntry.create(attribute: 'level',
                            old_value: Contact::VALID_LEVELS[nil],
                            changed_at: '2012-11-26 18:00:00 UTC'.to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
        HistoryEntry.create(attribute: 'level',
                            old_value: Contact::VALID_LEVELS['sádhaka'],
                            changed_at: '2012-11-26 18:58:21 UTC'.to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
        HistoryEntry.create(attribute: 'level',
                            old_value: Contact::VALID_LEVELS['aspirante'],
                            changed_at: '2012-11-26 23:41:16 UTC'.to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
      end
      specify do
        @contact.history_entries.where(attribute: 'level').each{|h|[
            DateTime.civil(2012,11,26,18,0,0,0),
            DateTime.civil(2012,11,26,18,58,21,0),
            DateTime.civil(2012,11,26,23,41,16,0)
        ].should include h.changed_at }
      end

      example { contacts_with_value_at('sádhaka', 1.year.ago).should_not include @contact }
      example { contacts_with_value_at('sádhaka', DateTime.civil(2012,11,26,18,57,0,0)).should include @contact }
      example { contacts_with_value_at(nil,1.year.ago).should include @contact }
      example { contacts_with_value_at('aspirante','2012-11-26 23:00:00 UTC').should include @contact }

      # helper
      def contacts_with_value_at(value,at)
        Contact.with_attribute_value_at('level',value,at)
      end
    end
  end

  describe "when level changes" do

    context "and :skip_level_change_activity is not set" do
      it "posts activity" do
        ActivityStream::Activity.any_instance.should_receive(:create)
        c = Contact.make_unsaved
        c.level = 'sádhaka'
        c.save
      end
    end

    context "and :skip_level_change_activity is false" do
      it "posts activity" do
        ActivityStream::Activity.any_instance.should_receive(:create)
        c = Contact.make_unsaved(skip_level_change_activity: false)
        c.level = 'sádhaka'
        c.save
      end
    end

    context "and :skip_level_change_activity is true" do
      it "doesnt post activity" do
        ActivityStream::Activity.any_instance.should_not_receive(:create)
        c = Contact.make_unsaved(skip_level_change_activity: true)
        c.level = 'sádhaka'
        c.save
      end
    end

  end

  it "sets level aspirante when first turned student" do
    c = Contact.make
    c.status = :student
    c.save
    c.level.should == 'aspirante'
  end

  it "should be able to use estimated age" do
    c = Contact.make(first_name: "alex", last_name: "falke", estimated_age: 30)
    c.should be_valid
  end

  describe "when receiving a value with extra white spaces" do
    context "sending an email" do
      before do
        @c = Contact.make(first_name: "Alex")
        @c.contact_attributes << Email.new(value: ' alex@mail.com ')
      end
      it "should should not raise an exception" do
        expect{@c.save!}.not_to raise_exception
      end
      it "should trim the values before saving them to the database" do
        @c.save
        @c.emails.last.value.should == "alex@mail.com"
      end
    end
    
    context "sending a telephone" do
      before do
        @c = Contact.make(first_name: "Alex")
        @c.save
        @c.contact_attributes << Telephone.new(value: ' 1554665555 ')
      end
      it "should should not raise an exception" do
        expect{@c.save!}.not_to raise_exception
      end
      it "should trim the values before saving them to the database" do
        @c.save
        @c.telephones.last.value.should == "1554665555"
      end
    end
  end
end
