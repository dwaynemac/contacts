require 'spec_helper'

describe MailchimpSynchronizer do
  let(:account){Account.make(name: 'myaccname')}
  let(:sync){MailchimpSynchronizer.new(account: account)}
  let(:contact){Contact.make(owner_id: account.id)}

  before do
    PadmaAccount.any_instance.stub(:locale).and_return("en")
    contact.contact_attributes << Email.make(account: account, value: "mail@mail.com")
  end

  describe "unsubscribe_contacts" do
    before do
      contact.accounts << account
      sync.status = :ready
      sync.save
    end
    it "queues job" do
      Delayed::Job.delete_all
      expect(Delayed::Job.count).to eq 0
      sync.unsubscribe_contacts
      sync.unsubscribe_contacts
      sync.unsubscribe_contacts
      sync.unsubscribe_contacts
      expect(Delayed::Job.count).to eq 4
    end
  end

  describe "#queue_subscribe_contacts" do
    let(:other_account){Account.make(name: 'othermyaccname')}
    let(:other_sync){MailchimpSynchronizer.new(account: other_account)}
    before do
      Delayed::Worker.delay_jobs = true
      contact.accounts << account
      contact.accounts << other_account
      sync.status = :ready
      sync.save
      other_sync.status = :ready
      other_sync.save
    end
    it "creates a new delayed_job" do
      Delayed::Job.delete_all
      expect(Delayed::Job.count).to eq 0
      sync.queue_subscribe_contacts
      expect(Delayed::Job.count).to eq 1
    end
    it "wont duplicate jobs" do
      Delayed::Job.delete_all
      expect(Delayed::Job.count).to eq 0
      sync.queue_subscribe_contacts
      sync.queue_subscribe_contacts
      sync.queue_subscribe_contacts
      expect(Delayed::Job.count).to eq 1
    end
    it "will create a job for each account" do
      Delayed::Job.delete_all
      expect(Delayed::Job.count).to eq 0
      sync.queue_subscribe_contacts
      sync.queue_subscribe_contacts
      sync.queue_subscribe_contacts
      other_sync.queue_subscribe_contacts
      other_sync.queue_subscribe_contacts
      other_sync.queue_subscribe_contacts
      expect(Delayed::Job.count).to eq 2
    end
  end
  
  describe "#subscribe_contacts" do
    describe "if status is not :ready" do
      before do
        contact.accounts << account
        sync.save
        sync.status = :failed
      end
      it "should do nothing" do
        Gibbon::Request.any_instance.should_not_receive(:lists)
        expect{sync.subscribe_contacts}.not_to raise_exception
        expect(sync.subscribe_contacts).to be_nil
      end
    end
    describe "if status is :ready" do
      before do
        contact.accounts << account
        sync.save
        sync.status = :ready
      end
      describe "if account is disabled" do
        before do
          PadmaAccount.stub(:find_with_rails_cache).and_return(PadmaAccount.new(enabled: false))
        end
        it "should do nothing" do
          Gibbon::Request.any_instance.should_not_receive(:batches)
          expect{sync.subscribe_contacts}.not_to raise_exception
          expect(sync.subscribe_contacts).to be_nil
        end
      end
      describe "if accounts is enabled" do
        before do
          PadmaAccount.stub(:find_with_rails_cache).and_return(PadmaAccount.new(enabled: true))
        end
        context "if mailchimp fails consistenly" do
          before do
            #MailchimpSynchronizer.any_instance.stub(:coefficient_group_valid?).and_return(true)
            #MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group)
            Gibbon::Request.any_instance.stub(:batches).and_raise(Gibbon::MailChimpError)
            stub_const("MailchimpSynchronizer::RETRIES", 0)
          end
          it "re-raises Gibbon::MailChimpError" do
            expect{sync.subscribe_contacts}.to raise_exception
          end
          it "sends email to padma admins" do
            deliveries = ActionMailer::Base.deliveries.count
            expect{sync.subscribe_contacts}.to raise_exception
            # Action Mailer should have one more mail delivered
            expect(ActionMailer::Base.deliveries.count).to eq (deliveries+1)
          end
        end
        context "if mailchimp fails erratically" do
          before do
            #MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group).and_return(nil)
            @exception_counts = 1
            Gibbon::Request.any_instance.stub(:body).and_return("1234")
            Gibbon::Request.any_instance.stub_chain(:batches, :create) do
              @exception_counts -= 1
              if @exception_counts >= 0
                raise Gibbon::MailChimpError
              else
                Gibbon::Request.new(api_key: "1234")
              end
            end
          end
          it "catches Gibbon::MailChimpError and retries" do
            expect{sync.subscribe_contacts}.not_to raise_exception
          end
        end
        context "on the first subscription" do
          context "all contacts should be send to mailchimp" do
            it "scopes all contacts" do
              Gibbon::Request.any_instance.stub(:body).and_return("1234")
              Gibbon::Request.any_instance.stub_chain(:batches, :create).and_return(Gibbon::Request.new(api_key: "1234"))
              #MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group).and_return(nil)
              @c = Contact.make
              @c.contact_attributes << Email.make(account: account, value: "mail2@mail.com")
              @c.accounts << account
              @c.save
              sync.api_key = "123123"
              sync.filter_method = "all"
              sync.save
    
              sync.last_synchronization.should be_nil
              sync.get_scope(true).count.should == 2
            end
          end
        end
        context "when subscription has been updated" do
          context "with filter_method: :all" do
            before do
              Gibbon::Request.any_instance.stub(:body).and_return("1234")
              Gibbon::Request.any_instance.stub_chain(:batches, :create).and_return(Gibbon::Request.new(api_key: "1234"))
              #MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group).and_return(nil)
              @c = Contact.make
              @c.accounts << account
              @c.contact_attributes << Email.make(account: account, value: "mail2@mail.com")
              @c.save
              sync.api_key = "123123"
              sync.filter_method = "all"
              sync.save
              sync.subscribe_contacts
            end
            describe "and no contact was has been updated since last sincronization" do
              it "should not get any contacts to subscribe" do
                sync.get_scope(true).count.should == 0
              end
            end
            describe "and one or more contacts had changes in between sincronizations" do
              it "only those contacts should be updated in mailchimp" do
                @c.last_name = "Falke"
                sleep(2)
                @c.save
    
                sync.get_scope(true).count.should == 1
              end
            end
          end
          context "with filter_method: :segments" do
            before do
              #MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group).and_return(nil)
              Gibbon::Request.any_instance.stub(:body).and_return({id: "1234"})
              Gibbon::Request.any_instance.stub_chain(:batches, :create).and_return(Gibbon::Request.new(api_key: "1234"))
              Gibbon::Request.any_instance.stub_chain(:lists, :segments, :create).and_return(Gibbon::Request.new(api_key: "1234"))
              @c = Contact.make(first_name: "Alex", last_name: "Halcon")
              @c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
              @c.accounts << account
              @c.contact_attributes << Email.make(account: account, value: "mail2@mail.com")
              @c.save
              sync.mailchimp_segments << MailchimpSegment.new(status: ["student"], followed_by: [])
              sync.api_key = "123123"
              sync.filter_method = "segments"
              sync.save
              sync.subscribe_contacts
            end
            describe "and no contact was has been updated since last sincronization" do
              it "should not get any contacts to subscribe" do
                sync.get_scope(true).count.should == 0
              end
            end
            describe "and one or more contacts had changes in between sincronizations" do
              it "only those contacts should be updated in mailchimp" do
                cs = Contact.make(first_name: "Beto", last_name: "Alonso")
                cs.accounts << account
                cs.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
                cs.contact_attributes << Email.make(account: account, value: "mail3@mail.com")
                @c.last_name = "Falke"
                sleep(2)
                cs.save
                @c.save
    
                sync.get_scope(true).count.should == 2
              end
            end
          end
        end
      end
    end
  end

  describe "#get_scope" do
    subject { sync.get_scope(true) }
    describe "when no segments" do
      it { should_not raise_exception }
    end
    context "when account does not have unlinked contacts" do
      before do
        c = Contact.make(first_name: "Hy Thuong", last_name: "Nguyen", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c.contact_attributes << Email.make(account: account, value: "mail3@mail.com")
        c = Contact.make(first_name: "Samsung", last_name: "Galaxy", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c.contact_attributes << Email.make(account: account, value: "mail4@mail.com")
        c = Contact.make(first_name: "Homer", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c.contact_attributes << Email.make(account: account, value: "mail5@mail.com")
        c = Contact.make(first_name: "Lisa", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :former_student)
        c.contact_attributes << Email.make(account: account, value: "mail36@mail.com")
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Bart", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.contact_attributes << Email.make(account: account, value: "mail323@mail.com")
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Maggie", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.contact_attributes << Email.make(account: account, value: "mail3323@mail.com")
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Marge", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.contact_attributes << Email.make(account: account, value: "mail33123@mail.com")
        c.coefficient_for_myaccname = "pmenos"
        c.save
        c = Contact.make(first_name: "Julieta", last_name: "Wertheimer", owner_id: account.id)
        c.contact_attributes << Email.make(account: account, value: "mail3311@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        sync.mailchimp_segments << MailchimpSegment.new(statuses: ["prospect"], followed_by: [], coefficients: ["perfil", "pmas"])
        sync.mailchimp_segments << MailchimpSegment.new(statuses: ["student"], followed_by: [], coefficients: [])
        sync.api_key = "123123"
        sync.last_synchronization = "1/1/2000 00:00"
        sync.filter_method = "segments"
        sync.save
      end
      it "should get correct scope" do
        sync.get_scope(true).count.should == 6
      end
    end
    context "when account has unlinked contacts" do
      before do
        c = Contact.make(first_name: "Hy Thuong", last_name: "Nguyen", owner_id: account.id)
        c.contact_attributes << Email.make(account: account, value: "mail3@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Samsung", last_name: "Galaxy")
        c.contact_attributes << Email.make(account: account, value: "mail3123@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Homer", last_name: "Simpson")
        c.contact_attributes << Email.make(account: account, value: "mail1@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Bart", last_name: "Simpson")
        c.contact_attributes << Email.make(account: account, value: "mail323@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Lisa", last_name: "Simpson")
        c.contact_attributes << Email.make(account: account, value: "mailas3@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :former_student)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Marge", last_name: "Simpson")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.contact_attributes << Email.make(account: account, value: "mail323@mail.com")
        c.coefficient_for_myaccname = "pmenos"
        c.save
        c = Contact.make(first_name: "Julieta", last_name: "Wertheimer")
        c.contact_attributes << Email.make(account: account, value: "mail3213@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c.coefficient_for_myaccname = "perfil"
        c.save
        # for some bizarre reason only onw unlink is not working, have to do it two times
        # only in this contact..
        c.unlink(account)
        c.unlink(account)
        c = Contact.make(first_name: "Maggie", last_name: "Simpson")
        c.contact_attributes << Email.make(account: account, value: "mail3123@mail.com")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c.unlink(account)
        sync.mailchimp_segments << MailchimpSegment.new(statuses: ["prospect"], followed_by: [], coefficients: ["perfil", "pmas"])
        sync.mailchimp_segments << MailchimpSegment.new(statuses: ["student"], followed_by: [], coefficients: [])
        sync.api_key = "123123"
        sync.last_synchronization = "1/1/2000 00:00"
        sync.filter_method = "segments"
        sync.save
      end
      it "should not count them" do
        Contact.where(first_name: "Julieta").first.owner.should be_nil
        Contact.where(first_name: "Maggie").first.owner.should be_nil
        account.contacts.count.should == 7
        sync.get_scope(true).count.should == 4
      end
    end
  end
  
  describe "#get_local_teacher" do
    subject { sync.get_local_teacher_for(contact) }
    
    describe "if contact has local teacher" do
      let(:contact){ Contact.make(local_teacher_for_myaccname: "dwayne.macgowan", owner_id: account.id) }
      it { should eq "dwayne.macgowan" }
    end
    
    describe "if contact has no local teacher" do
      let(:contact){ Contact.make }
      it { should be_nil }
    end
  end
  
  describe "#get_system_status" do
    subject { sync.get_system_status(contact) }
    describe "for contact with local_status :student" do
      let(:contact){ Contact.make(local_status_for_myaccname: :student, owner_id: account.id) }
      it { should eq '|s||ps||sf|' }
    end
    describe "for contact with local_status 'student'" do
      let(:contact){ Contact.make(local_status_for_myaccname: "student", owner_id: account.id) }
      it { should eq '|s||ps||sf|' }
    end
  end

  describe "#get_primary_attribute_value" do
    describe "if contact has none" do
      it "returns nil" do
        c = Contact.make(first_name: "Alex")
        expect(sync.get_primary_attribute_value(c,'Email')).to be_nil
      end
    end
    describe "if contact has" do
      let(:email_value){'dwa@sd.co'}
      before do
        contact.contact_attributes << Email.make(account: account, value: email_value, primary: true)
      end

      it "returns the value" do 
        expect(sync.get_primary_attribute_value(contact,'Email')).to eq email_value
      end
    end
  end

  describe "#get_status_translation" do
    describe "if contact has no local_status" do
      it "returns ''" do
        expect(sync.get_status_translation(contact)).to eq ''
      end
    end
  end

  describe "#get_coefficient_translation" do
    describe "if contacts has no coefficient" do
      it "return 'unknown'" do
        expect(sync.get_coefficient_translation(contact)).to eq "unknown"
      end
    end
  end

  describe "get_gender_translation" do
    describe "if contact's gender is nil" do
      before do
        contact.update_attribute :gender, nil
      end
      it "returns ''" do
        expect(sync.get_gender_translation(contact)).to eq ''
      end
    end
    describe "if contact's gender is not set" do
      before do
        contact.update_attribute :gender, ''
      end
      it "returns ''" do
        expect(sync.get_gender_translation(contact)).to eq ''
      end
    end
    describe "if contact's gender is male" do
      before do
        contact.update_attribute :gender, 'male'
      end
      it "returns i18n key 'mailchimp.gender.male'" do
        expect(sync.get_gender_translation(contact)).to eq I18n.t('mailchimp.gender.male')
      end
    end
    describe "if contact's gender is female" do
      before do
        contact.update_attribute :gender, 'female'
      end
      it "returns i18n key 'mailchimp.gender.female'" do

        expect(sync.get_gender_translation(contact)).to eq I18n.t('mailchimp.gender.female')
      end
    end
  end

  describe "on create" do
    it "should set status to :setting_up" do
      ms = MailchimpSynchronizer.new
      ms.account = account
      ms.save
      ms.status.should == :setting_up
    end
  end

  describe "#is_in_list" do
    context "contact is subscribed to list" do
      before do
        @ms = MailchimpSynchronizer.new
        @ms.account = account
        @ms.save
        Gibbon::Request.any_instance.stub(:body).and_return({"status" => "subscribed"})
        Gibbon::Request.any_instance.stub_chain(:lists, :members, :retrieve).and_return(Gibbon::Request.new(api_key: "1234"))
      end
      it "should return true" do
        @ms.is_in_list?("mail@mail.com").should be_truthy
      end
    end
    context "contact is unsubscribed or not in list" do
      before do
        @ms = MailchimpSynchronizer.new
        @ms.account = account
        @ms.save
        Gibbon::Request.any_instance.stub(:body).and_return({"status" => "unsubscribed"})
        Gibbon::Request.any_instance.stub_chain(:lists, :members, :retrieve).and_return(Gibbon::Request.new(api_key: "1234"))
      end
      it "should return false" do
        @ms.is_in_list?("mail@value.com").should be_falsey
      end
    end
  end

  describe "#coefficient_group_valid?" do
    before do
      @ms = MailchimpSynchronizer.new
      @ms.account = account
      @ms.list_id = "5555"
      @ms.api_key = "123123"
      @ms.save
      Gibbon::Request.any_instance.stub_chain(:lists, :interest_categories, :retrieve, :body).and_return({"title" => "Coefficient"})
      Gibbon::Request.any_instance.stub_chain(:lists, 
                                              :interest_categories, 
                                              :interests, 
                                              :retrieve, 
                                              :body).and_return(
                                                {
                                                  "total_items" => 5,
                                                  "interests" => 
                                                  [
                                                    {
                                                      "name" => "perfil",
                                                      "id" => 1
                                                    },
                                                    {
                                                      "name" => "np",
                                                      "id" => 2
                                                    },
                                                    {
                                                      "name" => "pmas",
                                                      "id" => 3
                                                    },
                                                    {
                                                      "name" => "pmenos",
                                                      "id" => 4
                                                    },
                                                    {
                                                      "name" => "unknown",
                                                      "id" => 5
                                                    }
                                                  ]
                                                }
                                              )
      @ms.stub(:email_admins_about_failure)
    end
    context "when coefficient group match" do
      before do
        @ms.coefficient_group = @ms.encode(
          {
            "id" => "1234",
            "interests" => 
            {
              "perfil" => 1,
              "np" => 2,
              "pmas" => 3,
              "pmenos" => 4,
              "unknown" => 5
            }
          }
        )
      end
      it "should be valid" do
        @ms.coefficient_group_valid?.should be_truthy
      end
    end
    context "when coefficient group is nil" do
      it "should not be valid" do
        @ms.coefficient_group_valid?.should be_falsey
      end
    end
    context "when coefficient group does not match" do
      before do
        @ms.coefficient_group = @ms.encode(
          {
            "id" => "1234",
            "interests" => 
            {
              "perfil" => 1,
              "pmas" => 3,
              "pmenos" => 4,
              "unknown" => 5
            }
          }
        )
      end
      it "should not be valid" do
        @ms.coefficient_group_valid?.should be_falsey
      end
      it "should not call method again on update" do
        expect(@ms).not_to receive(:check_coefficient_group)
        @ms.coefficient_group_valid?
      end
    end
  end

  describe "#find_or_create_coefficients_group" do
    before do
      @ms = MailchimpSynchronizer.new
      @ms.account = account
      @ms.list_id = "5555"
      @ms.api_key = "123123"
      @ms.save
      Gibbon::Request.any_instance.stub(:body).and_return({"id" => "1234"})
      Gibbon::Request.any_instance.stub_chain(:lists, :interest_categories, :create).and_return(Gibbon::Request.new(api_key: "1234"))
      Gibbon::Request.any_instance.stub_chain(:lists, 
                                              :interest_categories, 
                                              :interests, 
                                              :create).and_return(Gibbon::Request.new(api_key: "1234"))
      @ms.stub(:email_admins_about_failure)
      @ms.stub(:email_admins_about_failure)
    end
    it "should not call callbacks" do
      expect(@ms).not_to receive(:check_coefficient_group)
      @ms.find_or_create_coefficients_group
    end
  end

=begin
  describe "on update" do
    before do
      @ms = MailchimpSynchronizer.new
      @ms.account = account
      @ms.save
    end
    context "when mailchimp configuration isn't finished" do
      before do
        @ms.list_id = "1234"
      end
      it "should not subscribe contacts" do
        MailchimpSynchronizer.any_instance.should_receive(:completed_initial_setup?).and_return(false)
        MailchimpSynchronizer.any_instance.should_not_receive(:subscribe_contacts)
        @ms.save
      end
    end
    context "when mailchimp configuration is finished" do
      before do
        @ms.list_id = "1234"
        @ms.api_key = "123123"
        @ms.save
        Gibbon::API.stub_chain(:lists, :segment_add).and_return({"id" => "1234"})
        @ms.mailchimp_segments.create(statuses: "", coefficients: "", gender: "", followed_by: "")
        @ms.filter_method = "segments"
      end
      it "should subscribe contacts" do
        MailchimpSynchronizer.any_instance.should_receive(:completed_initial_setup?).and_return(true)
        MailchimpSynchronizer.any_instance.should_receive(:queue_subscribe_contacts)
        @ms.save
      end
    end
  end
=end

end
