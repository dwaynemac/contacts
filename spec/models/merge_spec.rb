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
      context "for ok contacts" do
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

        let(:merge){Merge.create(:first_contact_id => @student_goku.id, :second_contact_id => @pr_goku_2a.id)}
        describe "#father" do
          it "returns father" do
            merge.father.should == @student_goku
          end
        end

        describe "#son" do
          it "returns son" do
            merge.son.should == @pr_goku_2a
          end
        end
      end
      context "for contacts without status" do
        before do
          @a = Contact.make first_name: 'son', last_name: 'goku'
          @b = Contact.make first_name: 'sons', last_name: 'goku'
        end
        it "should no raise exception" do
          m = Merge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{m.save!}.not_to raise_exception
        end
      end
      context "when one contact has no status" do
        before do
          @a = Contact.make first_name: 'son', last_name: 'goku', status: 'student'
          @b = Contact.make first_name: 'sons', last_name: 'goku'
        end
        it "should no raise exception" do
          m = Merge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{m.save!}.not_to raise_exception
        end
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

      it "should not fail if contact has no level" do
        @a = Contact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
        @b = Contact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

        m = Merge.new(first_contact_id: @a.id, second_contact_id: @b.id)
        expect{m.save}.not_to raise_exception
      end

      it "should not fail if contacts have local_status in same acc and one is blank" do
        account = Account.make

        @a = Contact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
        @b = Contact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

        @a.local_unique_attributes << LocalStatus.make(value: '', account: account)
        @b.local_unique_attributes << LocalStatus.make(value: :student, account: account)

        m = Merge.new(first_contact_id: @a.id, second_contact_id: @b.id)
        expect{m.save}.not_to raise_exception
      end

      context "for contacts :prospect and :'' in same account" do
        before do
          account = Account.make

          @a = Contact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
          @b = Contact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

          @a.local_unique_attributes << LocalStatus.make(value: :prospect, account: account)
          @b.local_unique_attributes << LocalStatus.make(value: '', account: account)

          @m = Merge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{@m.save}.not_to raise_exception
        end
        it "should not set warnings" do
          @m.warnings.should == {}
        end
      end


      context "for contacts :student and :prospect in same account" do
        before do
          account = Account.make

          @a = Contact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
          @b = Contact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

          @a.local_unique_attributes << LocalStatus.make(value: :prospect, account: account)
          @b.local_unique_attributes << LocalStatus.make(value: :student, account: account)

          @m = Merge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{@m.save}.not_to raise_exception
        end
        it "should not set warnings" do
          @m.warnings.should == {}
        end
      end

      context "when both contacts are :student in different accounts" do
        let(:account_a){Account.make}
        let(:account_b){Account.make}
        before do
          contact_a = Contact.make
          contact_b = Contact.make(first_name: contact_a.first_name, last_name: contact_a.last_name)

          contact_a.local_unique_attributes << LocalStatus.make(value: :student, account: account_a)
          contact_b.local_unique_attributes << LocalStatus.make(value: :student, account: account_b)

          contact_b.owner = account_a

          contact_a.save!
          contact_b.save!

          @merge = Merge.new(first_contact: contact_a, second_contact: contact_b)
          @merge.save
        end
        it "should set warnings" do
          @merge.warnings.should_not be_empty
        end
      end
    end
  end

  describe "#merge" do
    let(:father){Contact.make(first_name: 'dwayne 2', last_name: 'macgowan', status: :student)}
    let(:son){Contact.make(first_name: 'dwayne', last_name: 'macgowan')}

    describe "contacts service" do
      context "when the avatar is being merged" do
        it "keeps sons avatar if the father has not an avatar" do
          extend ActionDispatch::TestProcess
          image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 
                                      'image/gif')
          @fc = Contact.make( first_name: 'foo',
                              last_name: 'bar',
                              status: :student)
          @sc = Contact.make( first_name: 'foo',
                              last_name: 'bar',
                              avatar: image)

          @m = Merge.new( first_contact_id: @fc.id,
                          second_contact_id: @sc.id)
          @m.save

          @m.start
          @fc.reload
          @fc.avatar.should_not be_nil
        end

        it "keeps sons avatar as an attachment if the father already has one" do
          extend ActionDispatch::TestProcess
          s_image = fixture_file_upload(
            'spec/support/ghibli_main_logo.gif',
            'image/gif'
          ) 
          f_image = fixture_file_upload(
            'spec/support/facebook.png',
            'image/png'
          )
          @fc = Contact.make( first_name: 'foo',
                              last_name: 'bar',
                              avatar: f_image,
                              status: :student)
          @sc = Contact.make( first_name: 'foo',
                              last_name: 'bar',
                              avatar: s_image)
          sc_avatar_name = @sc[:avatar]

          @m = Merge.new( first_contact_id: @fc.id,
                          second_contact_id: @sc.id)
          @m.save
          @m.start

          @fc.reload
          @fc.attachments.first.name.should == sc_avatar_name
        end
      end
    end
    
    describe "delegates to ActivityStream service" do
      let(:merge){Merge.new(first_contact_id: father.id, second_contact_id: son.id)}
      before do
        mock = ActivityStream::Merge.new
        ActivityStream::Merge.should_receive(:new).with(parent_id: father.id.to_s, son_id: son.id.to_s).and_return(mock)
        merge.save
      end
      context "when connection is successfull" do
        context "and merge succesfull" do
          before { ActivityStream::Merge.any_instance.should_receive(:create).and_return(true) }
          it "sets services['activity_stream'] to true" do
            merge.start
            merge.services['activity_stream'].should be_truthy
          end
        end
        context "and merge fails" do
          before { ActivityStream::Merge.any_instance.should_receive(:create).and_return(false) }
          it "leaves services['activity_stream'] in false" do
            merge.start
            merge.services['activity_stream'].should be_falsy
          end
          it "stores message 'errors.merge.services.merge_failed' in :crm_service" do
            merge.start
            merge.reload
            merge.messages['activity_stream_service'].should == I18n.t('errors.merge.services.merge_failed')
          end
        end
      end
      context "when connection fails" do
        before { ActivityStream::Merge.any_instance.should_receive(:create).and_return(nil) }
        it "leaves services['activity_stream'] in false" do
          merge.start
          merge.reload
          merge.services['activity_stream'].should be_falsy
        end
        it "stores message 'errors.merge.services.connection_failed' in :crm_service" do
          merge.start
          merge.reload
          merge.messages['activity_stream_service'].should == I18n.t('errors.merge.services.connection_failed')
        end
      end
    end

    describe "delegates to CRM service" do
      let(:merge){Merge.new(first_contact_id: father.id, second_contact_id: son.id)}
      before do
        mock = CrmMerge.new
        CrmMerge.should_receive(:new).and_return(mock)
        merge.save
      end
      context "when connection is successfull" do
        context "and merge succesfull" do
          before { CrmMerge.any_instance.should_receive(:create).and_return(true) }
          it "sets services['crm'] to true" do
            merge.start
            merge.services['crm'].should be_truthy
          end
        end
        context "and merge fails" do
          before { CrmMerge.any_instance.should_receive(:create).and_return(false) }
          it "leaves services['crm'] in false" do
            merge.start
            merge.services['crm'].should be_falsy
          end
          it "stores message 'errors.merge.services.merge_failed' in :crm_service" do
            merge.start
            merge.reload
            merge.messages['crm_service'].should == I18n.t('errors.merge.services.merge_failed')
          end
        end
      end
      context "when connection fails" do
        before { CrmMerge.any_instance.should_receive(:create).and_return(nil) }
        it "leaves services['crm'] in false" do
          merge.start
          merge.services['crm'].should be_falsy
        end
        it "stores message 'errors.merge.services.connection_failed' in :crm_service" do
          merge.start
          merge.reload
          merge.messages['crm_service'].should == I18n.t('errors.merge.services.connection_failed')
        end
      end
    end

    it "should persist services progress" do
      m = Merge.make(first_contact_id: son.id, second_contact_id: father.id)

      activities_merge = ActivityStream::Merge.new
      ActivityStream::Merge.should_receive(:new).with(parent_id: father.id.to_s, son_id: son.id.to_s).and_return(activities_merge)
      ActivityStream::Merge.any_instance.should_receive(:create).and_return(true)

      crm_merge = CrmMerge.new
      CrmMerge.should_receive(:new).with(parent_id: father.id, son_id: son.id).and_return(crm_merge)
      CrmMerge.any_instance.should_receive(:create).and_return(true)

      m.start

      backup_services = m.services.dup

      m.reload

      m.services.should == backup_services

    end
  end

  describe "Merging Incomplete" do

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
      @father = Contact.make(first_name: "Son",
                             last_name: "Goku",
                             level: "aspirante",
                             lists: [@father_list],
                             owner: @account_1,
                             accounts: [@account_1,@account_2]
                            )

      @father.local_unique_attributes << LocalStatus.make(:value => :student, :account => @account_1)
      @father.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => @account_2)

      @father.local_unique_attributes << LocalTeacher.make(:value => 'Roshi', :account => @account_1)

      @father.contact_attributes << [@contact_attributes['father_telephone'], @contact_attributes['father_email']]

      @father.save

      @check_link_account = Account.make
      #Son
      @son = Contact.make(first_name: "Son",
                          last_name: "Goku2",
                          level: "maestro",
                          lists: [@son_list],
                          owner: @account_1,
                          accounts: [@account_1, @account_2, @account_3, @check_link_account]
                         )

      @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => @account_1)
      @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => @account_2)
      @son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => @account_3)

      @son.local_unique_attributes << LocalTeacher.make(:value => 'Kami', :account => @account_1)
      @son.local_unique_attributes << LocalTeacher.make(:value => 'Kaio', :account => @account_2)

      @son.contact_attributes << [@contact_attributes['son_telephone'], @contact_attributes['son_email']]

      @son.save

      # it should call ActivityStream API (expectation has to be befare call to @m.start)
      mock = ActivityStream::Merge.new
      ActivityStream::Merge.should_receive(:new).with(parent_id: @father.id.to_s, son_id: @son.id.to_s).and_return(mock)
      ActivityStream::Merge.any_instance.should_receive(:create).and_return(true)

      # it should call Crm API
      mock = CrmMerge.new
      CrmMerge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
      CrmMerge.any_instance.should_receive(:create).and_return(false)


      @m = Merge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
      @m.save

      @m.should be_pending_confirmation
      @m.confirm
      @m.start

      @father.reload
    end

    it "should have all the contact attributes" do
      @contact_attributes.values.each do |cd|
        @father.contact_attributes.where(
          :_type => cd._type,
          :value => cd.value,
          :account_id => cd.account_id
        ).exists?.should == true
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

    it "should keep links to all accounts" do
      expect(@check_link_account).to be_in @father.accounts
    end

    describe "keeps son's first_name as a custom_attributes" do
      let(:old_first_name){ @father.contact_attributes.where(:name => "old_first_name").first }
      subject{old_first_name}
      its(:value) { should == 'Son' }
      its(:account) { should == @father.owner }
      it { should be_public }
    end

    describe "keeps son's last_name as a custom attribute" do
      let(:old_last_name){ @father.contact_attributes.where(:name => "old_last_name").first }
      subject{old_last_name}
      its(:value){ should == 'Goku2' }
      its(:account){ should == @father.owner }
      it { should be_public }
    end

    it "should keep record of migrated services" do
      @m.services['activity_stream'].should be_truthy
    end

    it "should keep record of not-migrated services" do
      @m.services['crm'].should be_falsy
      @m.should be_pending
    end
  end

  describe "Merging Complete" do
    context "if contacts are similar only by contact attributes" do
      before do
        @account_1 = Account.make
        @account_2 = Account.make

        @father = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "maestro")
        @father.local_unique_attributes << LocalStatus.make(:value => :student, :account => @account_1)
        @father.local_unique_attributes << LocalTeacher.make(value: 'teacher_1', account: @account_1)
        @father.contact_attributes << Email.make(value: 'same@mail.com')
        @father.save(validate: false)

        @son = Contact.make(:first_name => "Sonito", :last_name => "Goku2", :level => "aspirante")
        @son.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => @account_2)
        @son.local_unique_attributes << LocalTeacher.make(value: 'teacher_2', account: @account_2)
        @father.contact_attributes << Email.make(value: 'same@mail.com')
        @son.save(validate: false)

        # it should call ActivityStream API (expectation has to be befare call to @m.start)
        mock = ActivityStream::Merge.new
        ActivityStream::Merge.should_receive(:new).with(parent_id: @father.id.to_s, son_id: @son.id.to_s).and_return(mock)
        ActivityStream::Merge.any_instance.should_receive(:create).and_return(true)

        # it should call Crm API
        mock = CrmMerge.new
        CrmMerge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
        CrmMerge.any_instance.should_receive(:create).and_return(true)
        
        # it should call Planning API
        mock = PlanningMerge.new
        PlanningMerge.should_receive(:new).with(father_id: @father.id, son_id: @son.id).and_return(mock)
        PlanningMerge.any_instance.should_receive(:create).and_return(true)
        
        # it should call Fnz API
        mock = FnzMerge.new
        FnzMerge.should_receive(:new).with(father_id: @father.id, son_id: @son.id).and_return(mock)
        FnzMerge.any_instance.should_receive(:create).and_return(true)

        @m = Merge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
        @m.save

        @m.start
      end

      it "should keep record of migrated services" do
        @m.reload
        @m.services['activity_stream'].should be_truthy
        @m.services['crm'].should be_truthy
        @m.services['contacts'].should be_truthy
        @m.should be_finished
      end

      it "should end in state :merged" do
        @m.reload
        @m.state.should == 'merged'
      end

      it "should keep global_teacher" do
        @father.reload.global_teacher_username.should == 'teacher_1'
      end

      it "should keep local_Teachers" do
        @father.reload
        ['teacher_1', 'teacher_2'].each do |teacher|
          @father.local_teachers.map(&:value).should include(teacher)
        end
      end
    end
    context "if contacts are similar by name" do
      before do
        @account_1 = Account.make
        @account_2 = Account.make

        @father = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "maestro")
        @father.local_unique_attributes << LocalStatus.make(:value => :student, :account => @account_1)
        @father.local_unique_attributes << LocalTeacher.make(value: 'teacher_1', account: @account_1)
        @father.save

        @son = Contact.make(:first_name => "Son", :last_name => "Goku2", :level => "aspirante")
        @son.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => @account_2)
        @son.local_unique_attributes << LocalTeacher.make(value: 'teacher_2', account: @account_2)
        @son.save

        # it should call ActivityStream API (expectation has to be befare call to @m.start)
        mock = ActivityStream::Merge.new
        ActivityStream::Merge.should_receive(:new).with(parent_id: @father.id.to_s, son_id: @son.id.to_s).and_return(mock)
        ActivityStream::Merge.any_instance.should_receive(:create).and_return(true)

        # it should call Crm API
        mock = CrmMerge.new
        CrmMerge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
        CrmMerge.any_instance.should_receive(:create).and_return(true)
        
        # it should call Planning API
        mock = PlanningMerge.new
        PlanningMerge.should_receive(:new).with(father_id: @father.id, son_id: @son.id).and_return(mock)
        PlanningMerge.any_instance.should_receive(:create).and_return(true)
        
        # it should call Fnz API
        mock = FnzMerge.new
        FnzMerge.should_receive(:new).with(father_id: @father.id, son_id: @son.id).and_return(mock)
        FnzMerge.any_instance.should_receive(:create).and_return(true)

        @m = Merge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
        @m.save

        @m.start
      end

      it "should keep record of migrated services" do
        @m.reload
        @m.services['activity_stream'].should be_truthy
        @m.services['crm'].should be_truthy
        @m.services['contacts'].should be_truthy
        @m.should be_finished
      end

      it "should end in state :merged" do
        @m.reload
        @m.state.should == 'merged'
      end

      it "should keep global_teacher" do
        @father.reload.global_teacher_username.should == 'teacher_1'
      end

      it "should keep local_Teachers" do
        @father.reload
        ['teacher_1', 'teacher_2'].each do |teacher|
         @father.local_teachers.map(&:value).should include(teacher)
        end
      end
    end

  end

  describe "#finished?" do
    let(:merge){Merge.make}
    subject{merge}
    context "when all services are merged" do
      before do
        Merge::SERVICES.keys.each{|s|merge.services[s]=true}
        merge.save
      end
      it { should be_finished }
    end
    context "when no services are merged" do
      before do
        Merge::SERVICES.keys.each{|s|merge.services[s]=false}
        merge.save
      end
      it { should_not be_finished }
    end
    context "when some services are merged" do
      before do
        Merge::SERVICES.keys.each{|s|merge.services[s]=false}
        merge.services['contacts']=true
        merge.save
      end
      it { should_not be_finished }
    end
    context "on a vanilla merge" do
      it { should_not be_finished }
    end
  end

  # creates a merge that has warnings.
  # code extracted from merge_spec.rb:157
  def create_merge_with_warnings()
    account_1 = Account.make
    account_2 = Account.make
    account_3 = Account.make

    contact_attributes = {
        'father_telephone' => Telephone.make(:value => '111111111'),
        'father_email' => Email.make(:value => 'fathermail.com'),
        'son_telephone' => Telephone.make(:value => '555555555'),
        'son_email' => Email.make(:value => 'sonmail.com')
    }

    father_list = List.make
    son_list = List.make

    #Father
    father = Contact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante", :lists => [father_list])

    father.local_unique_attributes << LocalStatus.make(:value => :student, :account => account_1)
    father.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => account_2)

    father.local_unique_attributes << LocalTeacher.make(:value => 'Roshi', :account => account_1)

    father.contact_attributes << [contact_attributes['father_telephone'], contact_attributes['father_email']]

    father.save

    #Son
    son = Contact.make(:first_name => "Son", :last_name => "Goku2", :level => "maestro", :lists => [son_list])

    son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_1)
    son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_2)
    son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_3)

    son.local_unique_attributes << LocalTeacher.make(:value => 'Kami', :account => account_1)
    son.local_unique_attributes << LocalTeacher.make(:value => 'Kaio', :account => account_2)

    son.contact_attributes << [contact_attributes['son_telephone'], contact_attributes['son_email']]

    son.save


    m = Merge.new(:first_contact_id => father.id, :second_contact_id => son.id)
    m.save

    m.should be_pending_confirmation

    m
  end
end

