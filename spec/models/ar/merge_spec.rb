require 'ar_spec_helper'

describe NewMerge do

  it { should validate_presence_of :first_contact_id }
  it { should validate_presence_of :second_contact_id }

  describe "Creation" do
    before do
      @goku1 = NewContact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante")

      @goku2 = NewContact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante")

      @gohan = NewContact.make(:first_name => "Son", :last_name => "Gohan", :level => "aspirante")
      i = NewIdentification.make(:category => :dni, :value => "2222222", :contact_id => @gohan.id)
      
      @gohan2 = NewContact.make(:first_name => "Son", :last_name => "Gohan", :level => "aspirante")
      i2 =  NewIdentification.make(:category => :dni, :value => "11111111", :contact_id => @gohan2.id)

    end

    it "should check for contacts existence" do
      m = NewMerge.create(:first_contact_id => "50a4f26976fc000007000006", :second_contact_id => @goku2.id)
      m.should_not be_valid
      m = NewMerge.create(:first_contact_id => @goku1.id, :second_contact_id => @goku2.id)
      m.should be_valid
    end

    it "should check for similarity of contacts" do
      m = NewMerge.make(:first_contact_id => @goku1.id, :second_contact_id => @gohan.id)
      m.should_not be_valid
      m = NewMerge.make(:first_contact_id => @gohan.id, :second_contact_id => @gohan2.id)
      m.should_not be_valid
    end

    it "should be in not_started state" do
      m = NewMerge.new(:first_contact_id => @goku1.id, :second_contact_id => @goku2.id)
      m.should be_embryonic  # RSpec magic for: m.embryonic?.should == true
    end

    describe "Father Choosing" do
      context "for ok contacts" do
        before do
          @student_goku = NewContact.make(:first_name => "Son", :last_name => "Goku", :status => :student, :level => "aspirante")
          @student_goku.save

          @pr_goku_2a = NewContact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect, :level => "aspirante")
          NewTelephone.make(:value => "5445234342", :contact_id => @pr_goku_2a.id)
          NewEmail.make(:value => "goku_two@email.com", :contact_id => @pr_goku_2a.id)

          @pr_goku_1a = NewContact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect, :level => "aspirante")
          NewEmail.make(value: 'goku_one@email.com', :contact_id => @pr_goku_1a.id)

          @new_pr_goku_1a = NewContact.make(:first_name => "Son", :last_name => "Goku", :status => :prospect, :level => "aspirante")
          NewEmail.make(value: 'goku_one_but_new@email.com', :contact_id => @new_pr_goku_1a.id)

        end

        it "should choose depending on status hierarchy (first criteria) - between prospect and student, student if chosen" do
          m = NewMerge.new(:first_contact_id => @student_goku.id, :second_contact_id => @pr_goku_2a.id)
          m.save
          m.father_id.should == @student_goku.id
        end

        it "should choose depending on amount of contact attributes if they share status (second criteria)" do
          m = NewMerge.new(:first_contact_id => @pr_goku_1a.id, :second_contact_id => @pr_goku_2a.id)
          m.save
          m.father_id.should == @pr_goku_2a.id
        end

        it "should choose depending on updated time if they share the amount of contact attributes (third criteria)" do
          m = NewMerge.new(
              :first_contact_id => @pr_goku_1a.id,
              :second_contact_id => @new_pr_goku_1a.id
          )
          m.save
          m.father_id.should == @new_pr_goku_1a.id
        end

        let(:merge){NewMerge.create(:first_contact_id => @student_goku.id, :second_contact_id => @pr_goku_2a.id)}
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
          @a = NewContact.make first_name: 'son', last_name: 'goku'
          @b = NewContact.make first_name: 'sons', last_name: 'goku'
        end
        it "should no raise exception" do
          m = NewMerge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{m.save!}.not_to raise_exception
        end
      end
      context "when one contact has no status" do
        before do
          @a = NewContact.make first_name: 'son', last_name: 'goku', status: 'student'
          @b = NewContact.make first_name: 'sons', last_name: 'goku'
        end
        it "should no raise exception" do
          m = NewMerge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{m.save!}.not_to raise_exception
        end
      end
    end

    describe "Look for Warnings" do

      it "should initialize NewMerge in pending_confirmation state when there are one or more warnings" do

        account_1 = NewAccount.make
        account_2 = NewAccount.make

        @father = NewContact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante")
        account_1.account_contacts.create(:contact_id => @father.id, :local_status => :student)
        account_2.account_contacts.create(:contact_id => @father.id, :local_status => :prospect)

        @son = NewContact.make(:first_name => "Son", :last_name => "Goku", :level => "maestro")
        account_1.account_contacts.create(:contact_id => @son.id, :local_status => :former_student)
        account_2.account_contacts.create(:contact_id => @son.id, :local_status => :former_student)

        m = NewMerge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
        m.save

        m.should be_pending_confirmation
        m.warnings.size.should > 0
        m.warnings['local_statuses'].size == 1
        m.warnings['local_statuses'].first == account_2.id

        m.warnings['level'].should == true
      end

      it "should not fail if contact has no level" do
        @a = NewContact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
        @b = NewContact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

        m = NewMerge.new(first_contact_id: @a.id, second_contact_id: @b.id)
        expect{m.save}.not_to raise_exception
      end

      it "should not fail if contacts have local_status in same acc and one is blank" do
        account = NewAccount.make

        @a = NewContact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
        @b = NewContact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

        account.account_contacts.create(:contact_id => @a.id, :local_status => '')
        account.account_contacts.create(:contact_id => @b.id, :local_status => :student)

        m = NewMerge.new(first_contact_id: @a.id, second_contact_id: @b.id)
        expect{m.save}.not_to raise_exception
      end

      context "for contacts :prospect and :'' in same account" do
        before do
          account = NewAccount.make

          @a = NewContact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
          @b = NewContact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

          account.account_contacts.create(:contact_id => @a.id, :local_status => :prospect)
          account.account_contacts.create(:contact_id => @b.id, :local_status => '')

          @m = NewMerge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{@m.save}.not_to raise_exception
        end
        it "should not set warnings" do
          @m.warnings.should == {}
        end
      end


      context "for contacts :student and :prospect in same account" do
        before do
          account = NewAccount.make

          @a = NewContact.make(owner: @acc, first_name: 'Bob', last_name: 'Marley')
          @b = NewContact.make(owner: @acc, first_name: 'Bobby', last_name: 'Marley')

          account.account_contacts.create(:contact_id => @a.id, :local_status => :prospect)
          account.account_contacts.create(:contact_id => @b.id, :local_status => :student)

          @m = NewMerge.new(first_contact_id: @a.id, second_contact_id: @b.id)
          expect{@m.save}.not_to raise_exception
        end
        it "should not set warnings" do
          @m.warnings.should == {}
        end
      end

      context "when both contacts are :student in different accounts" do
        let(:account_a){NewAccount.make}
        let(:account_b){NewAccount.make}
        before do
          contact_a = NewContact.make
          contact_b = NewContact.make(first_name: contact_a.first_name, last_name: contact_a.last_name)

          account_a.account_contacts.create(:contact_id => contact_a.id, :local_status => :student)
          account_b.account_contacts.create(:contact_id => contact_b.id, :local_status => :student)

          contact_b.owner = account_a

          contact_a.save!
          contact_b.save!

          @merge = NewMerge.new(first_contact_id: contact_a.id, second_contact_id: contact_b.id)
          @merge.save
        end
        it "should set warnings" do
          @merge.warnings.should_not be_empty
        end
      end
    end
  end

  describe "#merge" do
    let(:father){NewContact.make(first_name: 'dwayne 2', last_name: 'macgowan', status: :student)}
    let(:son){NewContact.make(first_name: 'dwayne', last_name: 'macgowan')}
    before do
      mailing_merge = MailingMerge.new
      MailingMerge.should_receive(:new).and_return(mailing_merge)
      MailingMerge.any_instance.should_receive(:create).and_return(true)

      attendance_merge = AttendanceMerge.new
      AttendanceMerge.should_receive(:new).and_return(attendance_merge)
      AttendanceMerge.any_instance.should_receive(:create).and_return(true)
    end

    describe "contacts service" do
      context "when the avatar is being merged" do
        it "keeps sons avatar if the father has not an avatar" do
          extend ActionDispatch::TestProcess
          image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 
                                      'image/gif')
          @fc = NewContact.make( first_name: 'foo',
                              last_name: 'bar',
                              status: :student)
          @sc = NewContact.make( first_name: 'foo',
                              last_name: 'bar',
                              avatar: image)

          @m = NewMerge.new( first_contact_id: @fc.id,
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
          @fc = NewContact.make( first_name: 'foo',
                              last_name: 'bar',
                              avatar: f_image,
                              status: :student)
          @sc = NewContact.make( first_name: 'foo',
                              last_name: 'bar',
                              avatar: s_image)
          sc_avatar_name = @sc[:avatar]

          @m = NewMerge.new( first_contact_id: @fc.id,
                          second_contact_id: @sc.id)
          @m.save
          @m.start

          @fc.reload
          @fc.attachments.first.name.should == sc_avatar_name
        end
      end
    end
    
    describe "delegates to ActivityStream service" do
      let(:merge){NewMerge.new(first_contact_id: father.id, second_contact_id: son.id)}
      before do
        mock = ActivityStream::Merge.new
        ActivityStream::Merge.should_receive(:new).with(parent_id: father.id, son_id: son.id).and_return(mock)
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
      let(:merge){NewMerge.new(first_contact_id: father.id, second_contact_id: son.id)}
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
      m = NewMerge.make(first_contact_id: son.id, second_contact_id: father.id)
      
      activities_merge = ActivityStream::Merge.new
      ActivityStream::Merge.should_receive(:new).with(parent_id: father.id, son_id: son.id).and_return(activities_merge)
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
      @contact_attributes = []

      @account_1 = NewAccount.make
      @account_2 = NewAccount.make
      @account_3 = NewAccount.make

      #Father
      @father = NewContact.make(first_name: "Son",
                             last_name: "Goku",
                             level: "aspirante",
                             owner: @account_1
                            )

      @account_1.account_contacts.create(:contact_id => @father.id, :local_status => :student, :local_teacher_username => "Roshi")
      @account_2.account_contacts.create(:contact_id => @father.id, :local_status => :prospect)

      @contact_attributes << NewTelephone.make(:value => '111111111', :contact_id => @father.id)
      @contact_attributes << NewEmail.make(:value => 'father@mail.com', :contact_id => @father.id)

      @father.save

      @check_link_account = NewAccount.make
      #Son
      @son = NewContact.make(first_name: "Son",
                          last_name: "Goku2",
                          level: "maestro",
                          owner: @account_1
                         )

      @account_1.account_contacts.create(:contact_id => @son.id, :local_status => :former_student, :local_teacher_username => "Kami")
      @account_2.account_contacts.create(:contact_id => @son.id, :local_status => :former_student, :local_teacher_username => "Kaio")
      @account_3.account_contacts.create(:contact_id => @son.id, :local_status => :former_student)
      @check_link_account.account_contacts.create(:contact_id => @son.id)


      @contact_attributes << NewTelephone.make(:value => '555555555', :contact_id => @son.id)
      @contact_attributes << NewEmail.make(:value => 'son@mail.com', :contact_id => @son.id)

      @son.save

      # it should call ActivityStream API (expectation has to be befare call to @m.start)
      mock = ActivityStream::Merge.new
      ActivityStream::Merge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
      ActivityStream::Merge.any_instance.should_receive(:create).and_return(true)

      # it should call Crm API
      mock = CrmMerge.new
      CrmMerge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
      CrmMerge.any_instance.should_receive(:create).and_return(false)

      mailing_merge = MailingMerge.new
      MailingMerge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mailing_merge)
      MailingMerge.any_instance.should_receive(:create).and_return(true)

      attendance_merge = AttendanceMerge.new
      AttendanceMerge.should_receive(:new).with(father_id: @father.id, son_id: @son.id).and_return(attendance_merge)
      AttendanceMerge.any_instance.should_receive(:create).and_return(true)

      @m = NewMerge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
      @m.save

      #@m.should be_pending_confirmation
      @m.confirm
      @m.start

      @father.reload
    end

    it "should have all the contact attributes" do
      @contact_attributes.each do |ca|
        @father.contact_attributes.where(
          :type => ca.type,
          :string_value => ca.string_value,
          :account_id => ca.account_id
        ).exists?.should == true
      end
    end

    it "should keep father's level" do
      @father.level.should == 'aspirante'
    end

    it "should keep one local status for each account keeping father's value in case of repetition" do
      @father.account_contacts.where(:account_id => @account_1.id).first.local_status.should == :student
      @father.account_contacts.where(:account_id => @account_2.id).first.local_status.should == :prospect
      @father.account_contacts.where(:account_id => @account_3.id).first.local_status.should == :former_student
    end

    it "should keep one local teacher for each account keeping father's teacher in case of repetition" do
      @father.account_contacts.where(:account_id => @account_1.id).first.local_teacher_username.should == 'Roshi'
      @father.account_contacts.where(:account_id => @account_2.id).first.local_teacher_username.should == 'Kaio'
    end

    it "should keep links to all accounts" do
      expect(@check_link_account).to be_in @father.accounts
    end

    describe "keeps son's first_name as a custom_attributes" do
      let(:old_first_name){ @father.contact_attributes.where(:category => "old_first_name").first }
      subject{old_first_name}
      its(:string_value) { should == 'Son' }
      its(:account) { should == @father.owner }
      it { should be_public }
    end

    describe "keeps son's last_name as a custom attribute" do
      let(:old_last_name){ @father.contact_attributes.where(:category => "old_last_name").first }
      subject{old_last_name}
      its(:string_value){ should == 'Goku2' }
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
        @account_1 = NewAccount.make
        @account_2 = NewAccount.make

        @father = NewContact.make(:first_name => "Son", :last_name => "Goku", :level => "maestro")
        @father.account_contacts.create(:local_status => :student, :local_teacher_username => 'teacher_1', :account => @account_1)
        NewEmail.make(string_value: 'same@mail.com', :contact_id => @father.id)
        
        @son = NewContact.make(:first_name => "Sonito", :last_name => "Goku2", :level => "aspirante")
        @son.account_contacts.create(:local_status => :prospect, :local_teacher_username => 'teacher_2', :account => @account_2)
        NewEmail.make(string_value: 'same@mail.com', :contact_id => @son.id)

        # it should call ActivityStream API (expectation has to be befare call to @m.start)
        mock = ActivityStream::Merge.new
        ActivityStream::Merge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
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

        # it should call Mailing API
        mock = MailingMerge.new
        MailingMerge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
        MailingMerge.any_instance.should_receive(:create).and_return(true)

        # it should call Attendance API
        mock = AttendanceMerge.new
        AttendanceMerge.should_receive(:new).with(father_id: @father.id, son_id: @son.id).and_return(mock)
        AttendanceMerge.any_instance.should_receive(:create).and_return(true)

        @m = NewMerge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
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
        @account_1 = NewAccount.make
        @account_2 = NewAccount.make

        @father = NewContact.make(:first_name => "Son", :last_name => "Goku", :level => "maestro")
        @father.account_contacts.create(:local_status => :student, :local_teacher_username => 'teacher_1', :account => @account_1)

        @son = NewContact.make(:first_name => "Son", :last_name => "Goku2", :level => "aspirante")
        @son.account_contacts.create(:local_status => :prospect, :local_teacher_username => 'teacher_2', :account => @account_2)

        # it should call ActivityStream API (expectation has to be befare call to @m.start)
        mock = ActivityStream::Merge.new
        ActivityStream::Merge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
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

        # it should call Mailing API
        mock = MailingMerge.new
        MailingMerge.should_receive(:new).with(parent_id: @father.id, son_id: @son.id).and_return(mock)
        MailingMerge.any_instance.should_receive(:create).and_return(true)

        # it should call Attendance API
        mock = AttendanceMerge.new
        AttendanceMerge.should_receive(:new).with(father_id: @father.id, son_id: @son.id).and_return(mock)
        AttendanceMerge.any_instance.should_receive(:create).and_return(true)

        @m = NewMerge.new(:first_contact_id => @father.id, :second_contact_id => @son.id)
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
    let(:merge){NewMerge.make}
    subject{merge}
    context "when all services are merged" do
      before do
        NewMerge::SERVICES.keys.each{|s|merge.services[s]=true}
        merge.save
      end
      it { should be_finished }
    end
    context "when no services are merged" do
      before do
        NewMerge::SERVICES.keys.each{|s|merge.services[s]=false}
        merge.save
      end
      it { should_not be_finished }
    end
    context "when some services are merged" do
      before do
        NewMerge::SERVICES.keys.each{|s|merge.services[s]=false}
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
    account_1 = NewAccount.make
    account_2 = NewAccount.make
    account_3 = NewAccount.make

    contact_attributes = {
        'father_telephone' => NewTelephone.make(:value => '111111111'),
        'father_email' => NewEmail.make(:value => 'fathermail.com'),
        'son_telephone' => NewTelephone.make(:value => '555555555'),
        'son_email' => NewEmail.make(:value => 'sonmail.com')
    }

    father_list = List.make
    son_list = List.make

    #Father
    father = NewContact.make(:first_name => "Son", :last_name => "Goku", :level => "aspirante", :lists => [father_list])

    father.local_unique_attributes << LocalStatus.make(:value => :student, :account => account_1)
    father.local_unique_attributes << LocalStatus.make(:value => :prospect, :account => account_2)

    father.local_unique_attributes << LocalTeacher.make(:value => 'Roshi', :account => account_1)

    father.contact_attributes << [contact_attributes['father_telephone'], contact_attributes['father_email']]

    father.save

    #Son
    son = NewContact.make(:first_name => "Son", :last_name => "Goku2", :level => "maestro", :lists => [son_list])

    son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_1)
    son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_2)
    son.local_unique_attributes << LocalStatus.make(:value => :former_student, :account => account_3)

    son.local_unique_attributes << LocalTeacher.make(:value => 'Kami', :account => account_1)
    son.local_unique_attributes << LocalTeacher.make(:value => 'Kaio', :account => account_2)

    son.contact_attributes << [contact_attributes['son_telephone'], contact_attributes['son_email']]

    son.save


    m = NewMerge.new(:first_contact_id => father.id, :second_contact_id => son.id)
    m.save

    m.should be_pending_confirmation

    m
  end
end

