# encoding: UTF-8
require 'ar_spec_helper'

describe NewContact do

  it { should have_many(:accounts).through(:account_contacts) }

  it { should have_many(:contact_attributes) }
  
  it { should belong_to :owner }

  it { should respond_to(:first_name, :normalized_first_name, :last_name, :normalized_last_name, :status, :gender, :level, :in_professional_training, :first_enrolled_on, :occupations) }

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

  it "saves mass-assigned dates if subtype manually set" do
    c = NewContact.new(
            first_name: "alex", 
            contact_attributes_attributes: [
              {"type" => "NewDateAttribute", "day" => "1", "month" => "1", "category" => "birthday"}]
            )
    c.contact_attributes.first.type = "NewDateAttribute"
    expect(c).to be_valid
  end

  describe "#first_enrolled_on" do
    it "is casted from String to Date" do
      c = NewContact.new first_enrolled_on: "2014-12-31"
      c.valid?
      expect(c.first_enrolled_on).to eq Date.civil(2014,12,31)
    end
  end

  describe "#updated_at" do
    let(:contact){NewContact.make}
    it "changes when a root attribute changes" do
      pre = contact.updated_at
      sleep 1
      contact.first_name = 'a new first name'
      contact.save
      post = contact.reload.updated_at
      post.should > pre
    end
    #
    # The following specs are a description of mongoid behaviour,
    # for documentation and explicitation.
    # It is not the preferred behaviour
    #
    it "DOES NOT change when an embedded document is added" do
      contact.contact_attributes.count.should == 0
      pre = contact.updated_at
      sleep 1
      NewEmail.make(:contact_id => contact.id)
      contact.reload.contact_attributes.count.should == 1
      post = contact.reload.updated_at
      post.should == pre
    end
    it "DOES NOT change when an embedded document is updated" do
      NewEmail.make(:contact_id => contact.id)
      pre = contact.reload.updated_at
      sleep 1
      contact.contact_attributes.last.value = 'new@mail.com'
      contact.save
      post = contact.reload.updated_at
      post.should == pre
    end
    it "DOES NOT change when an embedded document is deleted" do
      NewEmail.make(:contact_id => contact.id)
      pre = contact.reload.updated_at
      sleep 1
      contact.contact_attributes.last.destroy
      post = contact.reload.updated_at
      post.should == pre
    end
  end

  describe "#tag_ids_for_request_account" do
    before do
      @account = NewAccount.make(name: "belgrano")
      @another_account = NewAccount.make
      @contact = NewContact.make(account_name: @account.name)
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
      @account = NewAccount.make(name: "belgrano")
      @another_account = NewAccount.make
      @contact = NewContact.make(account_name: @account.name)
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
      @contact= NewContact.make(:owner => NewAccount.make, level: 'chêla')
      @contact.local_unique_attributes << LocalTeacher.make(account: NewAccount.first)

      @contact.reload.history_entries.delete_all
      # 20121121 '' -> 'sádhaka'
      # 20121221 'sádhaka' -> 'yôgin'
      # 20131121 'yôgin' -> 'chêla'
      add_level_hchange('',DateTime.civil(2012,11,21,20,34,39).to_time)
      add_level_hchange('sádhaka',DateTime.civil(2012,12,21,20,34,39).to_time)
      add_level_hchange('yôgin',DateTime.civil(2013,11,21,20,34,39).to_time)
      @contact.history_entries.count.should == 3
    end
    it "should not include owner_id" do
      @contact.as_json({mode: 'all'}).should_not have_key 'owner_id'
    end
    it "should inclue owner_name" do
      @contact.as_json({mode: 'all'}).should have_key 'owner_name'
    end
    it "should include :coefficients_counts key" do
      @contact.as_json({mode: 'all'}).should have_key 'coefficients_counts'
    end
    it "should include global_teacher_username" do
      @contact.as_json({mode: 'all'}).should have_key 'global_teacher_username'
    end
    it "includes #in_active_merge" do
      @contact.as_json({mode: 'all'}).should have_key 'in_active_merge'
    end
    context "account specified" do
      subject { @contact.as_json(account: NewAccount.first, mode: 'all')}
      it { should have_key 'coefficient'}
      it { should have_key 'local_teacher' }
    end
    context "account not specified" do
      subject { @contact.as_json(mode: 'all')}
      it { should_not have_key 'coefficient' }
      it { should_not have_key 'local_teacher' }
    end
    describe "with option select" do
      describe "'all'" do
        it "still works for backward compatibility." do
          expect{@contact.as_json(select: 'all')}.not_to raise_exception
        end
      end
      describe "with attributes names" do
        it "includes id and chosen attributes" do
          keys = @contact.as_json(select: [:first_name]).keys
          keys.size.should == 2
          keys == [:id, :first_name]
        end
      end
      describe "with attribute hash where key is attribute and value is reference date" do
        let(:json){@contact.as_json(select: [:first_name, level: '2012-12-1'])}
        it "includes attribute from keys" do
          json.keys.should == %W(first_name _id level)
        end
        it "returns value at given date in value" do
          json['level'] == 'sádhaka'
        end
      end
      describe "with attribute hash where key is attribute and value is reference date" do
        let(:json){@contact.as_json(select: [:first_name, :last_name, nil])}
        it "includes attribute from keys" do
          json.keys.should == %W(first_name last_name _id )
        end
      end
    end
  end

  describe "#coefficients_counts" do
    it "should return all coeficients, even if zero" do
      subj = NewContact.make.coefficients_counts
      Coefficient::VALID_VALUES.each do |vv|
        subj.should have_key(vv)
      end
    end
    it "should count coefficients grouping by value" do
      c = NewContact.make
      3.times { c.local_unique_attributes << Coefficient.new(value: 'fp', account: NewAccount.make) }
      2.times { c.local_unique_attributes << Coefficient.new(value: 'perfil', account: NewAccount.make) }
      5.times { c.local_unique_attributes << Coefficient.new(value: 'pmas', account: NewAccount.make) }

      c.coefficients_counts['fp'].should == 3
      c.coefficients_counts['pmenos'].should == 0
      c.coefficients_counts['perfil'].should == 2
      c.coefficients_counts['pmas'].should == 5
    end
  end

  describe "#mobiles" do
    before do
      @con = NewContact.make_unsaved
      @con.contact_attributes << NewTelephone.make_unsaved(category: 'mobile')
      @con.contact_attributes << NewTelephone.make_unsaved(category: 'mobile')
      @con.contact_attributes << NewTelephone.make_unsaved(category: 'home')
      @con.contact_attributes << NewEmail.make_unsaved
    end
    it "should return all mobiles" do
      @con.mobiles.count.should == 2
    end
  end

  describe "update_status!" do
    it "should be :student if there is any local_status :student" do
      ls = LocalStatus.make(value: :student)
      ls2 = LocalStatus.make(value: :prospect)
      c = NewContact.make
      c.local_unique_attributes << ls
      c.local_unique_attributes << ls2
      c.update_status!
      c.status.should == :student
    end
    it "should be :former_student if there is any local_status :former_student and no :student" do
      c = NewContact.make(local_unique_attributes: [LocalStatus.make(value: :former_student),LocalStatus.make(value: :prospect)])
      c.status.should == :former_student
    end
    it "should be :prospect if there is any local_status :prospect and no :student or :former_student" do
      c = NewContact.make(local_unique_attributes: [LocalStatus.make(value: :prospect)])
      c.status.should == :prospect
    end
    it "should update status correctly if status is nil" do
      account = NewAccount.make(name: "accname")
      c = NewContact.make(local_unique_attributes: nil, owner: account)
      c.status = nil
      c.save!
      ls = LocalStatus.make(value: :student)
      c.local_status_for_accname.should be_nil
      c.local_unique_attributes << ls
      c.update_status!
      c.status.should == :student
    end
  end

  describe "local_status=(account_id,new_status)" do
    before do
      @contact = NewContact.make
      @account = NewAccount.make
      @contact.local_unique_attributes << LocalStatus.make
      @contact.local_unique_attributes << LocalStatus.make(account: @account)
    end
    it "should create local_status for that account if non-existant" do
      @contact.local_statuses.count.should == 2
      account = NewAccount.make
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
      @contact = NewContact.make
    end

    it "should return local_xxx for account named yyy" do
      c = @contact
      a = NewAccount.make(name: 'yyy')
      lua = LocalUniqueAttribute.new(account: a, value: 'thevalue')
      lua._type = 'Xxx'
      c.contact_attributes << lua
      c.save!
      c.reload
      c.xxx_for_yyy.should == 'thevalue'
    end

    it "should create local_xxx for that account if non-existant" do
      x = @contact.contact_attributes.count
      account = NewAccount.make(name: 'accname')
      @contact.xxx_for_accname=('new value')
      @contact.save! && @contact.reload
      @contact.local_unique_attributes.where('_type' => 'Xxx', account_id: account.id).first.try(:value).should == 'new value'
      @contact.local_unique_attributes.count.should == x+1
    end

    it "should change local_xxx for that accounts if it exists" do
      account = NewAccount.make(name: 'accname')
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


  describe "#create with nested attribute params" do
    before do
      @account = NewAccount.make
      @contact = NewContact.create(NewContact.plan(:owner => @account, :contact_attributes => [NewContactAttribute.plan(:account => nil)]))
    end

    it "should set the owner on new attributes" do
      @contact.contact_attributes.first.account.should == @account
    end
  end

  describe "#save with nested attribute params" do
    before do
      @account = NewAccount.make
      @contact = NewContact.create(NewContact.plan(:owner => @account))
      @contact.update_attributes(:contact_attributes => [NewContactAttribute.plan(:account => nil)])
    end

    it "should set the owner on new attributes" do
      @contact.contact_attributes.first.account.should == @account
    end
  end

  describe "mongoid_search" do
    describe "Email search" do
      before do
        account = NewAccount.make

        @first_name = NewContact.make(first_name: "dwayne")
        @first_name.contact_attributes << NewTelephone.new(account_id: account._id, value: "1234")
        @first_name.save

        @email = NewContact.make(last_name: "mac")
        @email.contact_attributes << NewEmail.new(account_id: account._id, value: "dwaynemac@gmail.com")
        @email.save

        @last_name = NewContact.make(first_name: "asdf", last_name: "dwayne")
      end
      it "should find by email" do
        NewContact.csearch("dwaynemac@gmail.com").should include(@email)
      end
    end

    describe "must match all words," do
      before do
        account = NewAccount.make

        @goku_contact = NewContact.make(first_name: "Son", last_name: "Goku")
        @gohan_contact = NewContact.make(first_name: "Son", last_name: "Gohan")
      end
      it "should find only Goku" do
        NewContact.csearch("Son Gok").should include(@goku_contact)
        NewContact.csearch("Son Gok").should_not include(@gohan_contact)
      end
    end
  end

  describe "#similar" do
    
    let(:account){ NewAccount.make }

    describe "when Homer Simpson exists" do
      before do
        contact = NewContact.make(first_name: "Homer", last_name: "Simpson", owner: account)
      end

      describe "a new contact named Marge Simpson" do
        before do
          @contact = NewContact.new(first_name: "Marge", last_name: "Simpson")
        end

        it "should not have possible duplicates" do
          @contact.similar.should be_empty
        end
      end

      describe "a new contact named Marge" do
        let(:contact){ NewContact.new(first_name: 'Marge')}
        it "should not have possible duplicates" do
          contact.similar.should be_empty
        end
      end

      describe "a new contact with same last name and a more complete first name" do
        before do
          @contact = NewContact.new(first_name: "Homer Jay", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }
      end
      
      describe "option :only_in_account_name" do
        it "ignores similar contacts on other accounts" do
          other_account = NewAccount.make
          
          homer = NewContact.make(first_name: "Homer Jay", last_name: "Simpson", owner: account)
          other_account_homer = NewContact.make(first_name: "Homer Jay", last_name: "Simpson", owner: other_account)
          other_account_homer.in?(homer.similar(only_in_account_name: account.name)).should be_falsy
          other_account_homer.in?(homer.similar).should be_truthy
          account.link(other_account_homer)
          other_account_homer.in?(homer.similar(only_in_account_name: account.name)).should be_truthy
        end
      end

      describe "matching should not be case sensitive" do
        before do
          @contact = NewContact.new(first_name: "hoMer Jay", last_name: "simPson")
        end

        it { @contact.similar.should_not be_empty }
      end

      describe "matching should ignore special characters" do
        before do
          @contact = NewContact.new(first_name: "hôMer Jáy", last_name: "simPsōn")
        end

        it { @contact.similar.should_not be_empty }
      end

      describe "a new contact with same last name and first name" do
        before do
          @contact = NewContact.new(first_name: "Homer", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.in?(@contact.similar).should_not be_truthy }
      end

      describe "an existing contact with same last name and first name" do
        before do
          @contact = NewContact.make(first_name: "Homer", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.in?(@contact.similar).should_not be_truthy }
      end
    end

    describe "when Homer Jay Simpson exists" do
      before do
        contact = NewContact.make(first_name: "Homer Jay", last_name: "Simpson")
      end

      describe "a new contact with same last name and only the first name" do
        before do
          @contact = NewContact.new(first_name: "Homer", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }
      end

      describe "a new contact with same last name and only the last name" do
        before do
          @contact = NewContact.new(first_name: "Jay", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.in?(@contact.similar).should_not be_truthy }
      end

      describe "a new contact with same last name and first name" do
        before do
          @contact = NewContact.new(first_name: "Homer Jay", last_name: "Simpson")
        end

        it { @contact.similar.should_not be_empty }

        it { @contact.in?(@contact.similar).should_not be_truthy }
      end
    end

    describe "when homer@simpson.com is registered" do
      before do
        @homer = NewContact.make(first_name: 'luis', last_name: 'lopez')
        NewEmail.make(value: 'homer@simpson.com', contact_id: @homer.id)
      end
      it "new contact should match it by mail" do
        contact = NewContact.new(first_name: 'Santiago', last_name: 'Santo')
        contact.contact_attributes << NewEmail.new(value: 'homer@simpson.com')
        @homer.in?(contact.similar).should be_truthy
      end
    end

    describe "when mobile 1540995071 is registered" do
      before do
        @homer = NewContact.make(first_name: 'Homero', last_name: 'Simpsonsizado')
        NewTelephone.make(value: '1540995071', category: 'mobile', contact_id: @homer.id)
      end

      describe "if ignore_name is set" do
        it "should ignore similar by name" do
          contact = NewContact.new(first_name: "Homer", last_name: "Simpson")
          contact.contact_attributes << NewTelephone.new(value: '123412314', category: 'mobile')
          expect(contact.similar).not_to be_empty
          expect(contact.similar(ignore_name: true)).to be_empty
        end
      end

      it "new contact should match it by mobile" do
        contact = NewContact.new(first_name: 'Juan', last_name: 'Perez')
        contact.contact_attributes << NewTelephone.new(value: '1540995071', category: 'mobile')
        @homer.in?(contact.similar).should be_truthy
      end
      
      it "new contact should not match if mobile differs" do
        contact = NewContact.new(first_name: 'Bob', last_name: 'Doe')
        contact.contact_attributes << NewTelephone.new(value: '15443340995071', category: 'mobile')
        @homer.in?(contact.similar).should_not be_truthy
      end
    end

    describe "when DNI 30366832 is registered" do
      before do
        @similar = NewContact.make(first_name: 'Dwayne', last_name: 'Macgowan')
        NewIdentification.make(value: '30366832', category: 'DNI', contact_id: @similar.id)
      end
      describe "a new contact" do
        before do
          @new_contact = NewContact.make_unsaved(first_name: 'Alejandro', last_name: 'Mac Gowan')
        end
        describe "with DNI 30366832" do
          before do
            @new_contact.contact_attributes << NewIdentification.make_unsaved(value: '30366832', category: 'DNI')
          end
          it "should have possible duplicates" do
            @similar.in?(@new_contact.similar).should be_truthy
          end
        end
        describe "with DNI 3/0.3_6 6.83-2" do
          before do
            @new_contact.contact_attributes << NewIdentification.make_unsaved(value: '3/0.3_6 6.83-2', category: 'DNI')
          end
          it "should have possible duplicates" do
            @similar.in?(@new_contact.similar).should be_truthy
          end
        end
        describe "with CPF 30366832" do
          before do
            @new_contact.contact_attributes << NewIdentification.make_unsaved(value: '30366832', category: 'CPF')
          end
          it "should not have possible duplicates" do
            debugger
            @new_contact.similar.should be_empty
          end
        end
      end
    end

  end

  describe "flagged to check for duplicates" do
    before do
      NewContact.make(first_name: "dwayne", last_name: "mac")
      @contact = NewContact.new(first_name: "dwayne", last_name: "mac", :check_duplicates => true)
    end

    it { @contact.should_not be_valid }
    describe "when validation is run" do
      before { @contact.valid? }

      it { @contact.errors[:possible_duplicates].should_not be_empty }
    end
  end

  describe "#owner_name" do
    before do
      @account = NewAccount.make
      @contact = NewContact.make(:owner => @account)
    end
    it "should return owner account name" do
      @contact.owner_name.should == @account.name
    end
    it "should set owner account by name" do
      new_account = NewAccount.make
      @contact.owner_name = new_account.name
      @contact.save
      @contact = NewContact.find(@contact.id)
      @contact.owner_name.should == new_account.name
    end
  end

  describe "#deep_error_messages" do
    before do
      @contact = NewContact.make
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
        NewEmail.make(value: 'invalid-mail', contact_id: @contact.id)
      end
      it "it should show 'Email xxx is invalid'" do
        @contact.should_not be_valid
        @contact.deep_error_messages.should include(contact_attributes: [["invalid-mail bad email format"]])
      end
    end
  end

  it "creates an activity when level changes" do
    c = NewContact.make(status: 'student')
    c.level = 'sádhaka'
    ActivityStream::Activity.any_instance.should_receive(:create)
    c.save
  end


  describe "History" do
    let(:contact) { NewContact.make(level: "yôgin", status: :student) }

    it "should record global teacher changes" do
      expect{contact.update_attribute(:global_teacher_username,'dwayne.macgowan')}.to change{contact.history_entries.count}
      contact.history_entries.last.old_value.should be_nil
      contact.history_entries.last.changed_at.should be_within(1.second).of(Time.now)
      contact.update_attribute(:global_teacher_username,'luis.perichon')
      contact.history_entries.last.old_value.should =='dwayne.macgowan'
    end

    it "should record level changes" do
      expect{contact.update_attribute(:level, "chêla")}.to change{contact.history_entries.count}
      contact.history_entries.last.old_value.should == NewContact::VALID_LEVELS["yôgin"]
      contact.history_entries.last.changed_at.should be_within(1.second).of(Time.now)
    end

    it "should record status changes" do
      expect{ contact.update_attribute(:status, :former_student) }.to change{contact.history_entries.count}.by(1)
      contact.history_entries.last.old_value.should == :student
      contact.history_entries.last.changed_at.should be_within(1.second).of(Time.now)
    end

    it "should record local_status changes" do
      account = NewAccount.make

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
        account = NewAccount.make

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

  
  describe "#attribute_value_at" do
    before do
      @contact = NewContact.make(level: 'chêla')
      @contact.reload.history_entries.delete_all
      add_level_hchange('',DateTime.civil(2012,11,21,20,34,39).to_time)
      add_level_hchange('sádhaka',DateTime.civil(2012,12,21,20,34,39).to_time)
      add_level_hchange('yôgin',DateTime.civil(2013,11,21,20,34,39).to_time)
      @contact.history_entries.count.should == 3
      # 20121121 '' -> 'sádhaka'
      # 20121221 'sádhaka' -> 'yôgin'
      # 20131121 'yôgin' -> 'chêla'
    end
    it "returns attribute value at given date" do
      @contact.attribute_value_at(:level,DateTime.civil(2012,11,20).to_time).should == ''
      @contact.attribute_value_at(:level,DateTime.civil(2012,11,22).to_time).should == 'sádhaka'
      @contact.attribute_value_at(:level,DateTime.civil(2012,12,22).to_time).should == 'yôgin'
      @contact.attribute_value_at(:level,DateTime.civil(2013,12,20).to_time).should == 'chêla'
    end
  end

  # real life example
  describe ".with_attribute_value_at" do
    context "if ref_date if current month's" do
      context "uses current values avoing slow query on HistoryEntry" do
        example do
          expect(NewContact.with_attribute_value_at('level','sádhaka',Date.today.end_of_month).selector)
            .to eq NewContact.api_where(level: 'sádhaka').selector
        end

        example do
          expect(NewContact.with_attribute_value_at('local_status_for_martinez','student',Date.today).selector)
            .to eq NewContact.api_where(local_status_for_martinez: 'student').selector
        end

        example do
          expect(NewContact.with_attribute_value_at('local_teacher_for_altoda_xv','evelyne.baldan',Date.today.end_of_month).selector)
            .to eq NewContact.api_where(local_teacher_for_altoda_xv: 'evelyne.baldan').selector
        end
      end
    end
    describe "with local_unique_attributes" do
      before do
        a = NewAccount.make(name: 'martinez')
        @contact = NewContact.make
        @contact.local_unique_attributes << LocalStatus.make(value: :student, account: a)
        @contact.save
        @contact.reload.history_entries.delete_all
        @contact.local_status_for_martinez.should == :student

        HistoryEntry.create(attribute: 'local_status_for_martinez',
                            old_value: '',
                            changed_at: "2012-11-21 20:34:39".to_time(:utc),
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
        HistoryEntry.create(attribute: 'local_status_for_martinez',
                            old_value: :prospect,
                            changed_at: "2012-11-21 20:35:50".to_time(:utc),
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
      end
      example { contacts_with_value_at('student', "2012-11-20").should_not include @contact}
      example { contacts_with_value_at('student',"2012-11-22").should include @contact}
      example { contacts_with_value_at('prospect',"2012-11-21").should_not include @contact }
      # helper
      def contacts_with_value_at(value,time)
        NewContact.with_attribute_value_at('local_status_for_martinez',value,time)
      end
    end
    describe "with level" do
      before do
        @contact = NewContact.make
        HistoryEntry.create(attribute: 'level',
                            old_value: NewContact::VALID_LEVELS[nil],
                            changed_at: '2012-11-26 18:00:00 UTC'.to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
        HistoryEntry.create(attribute: 'level',
                            old_value: NewContact::VALID_LEVELS['sádhaka'],
                            changed_at: '2012-11-27 18:58:21 UTC'.to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
        HistoryEntry.create(attribute: 'level',
                            old_value: NewContact::VALID_LEVELS['aspirante'],
                            changed_at: '2012-11-28 23:41:16 UTC'.to_time,
                            historiable_type: 'Contact',
                            historiable_id: @contact._id
        )
      end
      specify do
        @contact.history_entries.where(attribute: 'level').each{|h|[
            DateTime.civil(2012,11,26,18,0,0,0),
            DateTime.civil(2012,11,27,18,58,21,0),
            DateTime.civil(2012,11,28,23,41,16,0)
        ].should include h.changed_at }
      end

      example { contacts_with_value_at('sádhaka', 1.year.ago).should_not include @contact }
      example { contacts_with_value_at('sádhaka', DateTime.civil(2012,11,26,18,57,0,0)).should include @contact }
      example { contacts_with_value_at(nil,1.year.ago).should include @contact }
      example { contacts_with_value_at('aspirante','2012-11-26 23:00:00 UTC').should_not include @contact }

      # helper
      def contacts_with_value_at(value,at)
        NewContact.with_attribute_value_at('level',value,at)
      end
    end
  end

  describe "when level changes" do

    context "and :skip_level_change_activity is not set" do
      it "posts activity" do
        ActivityStream::Activity.any_instance.should_receive(:create)
        c = NewContact.make_unsaved
        c.level = 'sádhaka'
        c.save
      end
    end

    context "and :skip_level_change_activity is false" do
      it "posts activity" do
        ActivityStream::Activity.any_instance.should_receive(:create)
        c = NewContact.make_unsaved(skip_level_change_activity: false)
        c.level = 'sádhaka'
        c.save
      end
    end

    context "and :skip_level_change_activity is true" do
      it "doesnt post activity" do
        ActivityStream::Activity.any_instance.should_not_receive(:create)
        c = NewContact.make_unsaved(skip_level_change_activity: true)
        c.level = 'sádhaka'
        c.save
      end
    end

  end

  it "sets level aspirante when first turned student" do
    c = NewContact.make
    c.status = :student
    c.save
    c.level.should == 'aspirante'
  end

  it "should be able to use estimated age" do
    c = NewContact.make(first_name: "alex", last_name: "falke", estimated_age: 30)
    c.should be_valid
  end

  it "stores when age whas estimated" do
    c = NewContact.make
    c.reload
    c.estimated_age_on.should be_nil
    c.estimated_age = 14
    c.save
    c.estimated_age_on.should == Date.today
    Date.stub(:today).and_return(1.month.ago.to_date)
    c.estimated_age = 20
    c.save
    c.estimated_age_on.should == 1.month.ago.to_date
    c.estimated_age = nil
    c.save
    c.estimated_age_on.should be_nil
  end

  describe "when receiving a value with extra white spaces" do
    context "sending an email" do
      before do
        @c = NewContact.make(first_name: "Alex")
        @c.contact_attributes << NewEmail.new(value: ' alex@mail.com ')
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
        @c = NewContact.make(first_name: "Alex")
        @c.save
        @c.contact_attributes << NewTelephone.new(value: ' 1554665555 ')
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
  
  def add_level_hchange(old_value, time)
    HistoryEntry.create(attribute: :level,
                        old_value: old_value,
                        changed_at: time,
                        historiable_type: 'Contact',
                        historiable_id: @contact._id
    )
  end
end 