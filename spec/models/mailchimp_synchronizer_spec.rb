require 'spec_helper'

describe MailchimpSynchronizer do
  let(:account){Account.make(name: 'myaccname')}
  let(:sync){MailchimpSynchronizer.new(account: account)}
  let(:contact){Contact.make}

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
    before do
      contact.accounts << account
      sync.save
      sync.status = :ready
    end
    context "if mailchimp fails consistenly" do
      before do
        MailchimpSynchronizer.any_instance.stub(:coefficient_group_valid?).and_return(true)
        MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group)
        Gibbon::API.any_instance.stub(:lists).and_raise(Gibbon::MailChimpError)
        stub_const("MailchimpSynchronizer::RETRIES", 1)
      end
      it "re-raises Gibbon::MailChimpError" do
        expect{sync.subscribe_contacts}.to raise_exception
      end
      it "sends email to padma admins" do
        deliveries = ActionMailer::Base.deliveries.count
        expect{sync.subscribe_contacts}.to raise_exception
        # Action Mailer should have one more mail delivered
        deliveries.should == ActionMailer::Base.deliveries.count - 1
      end
    end
    context "if mailchimp fails erratically" do
      before do
        MailchimpSynchronizer.any_instance.stub(:coefficient_group_valid?).and_return(true)
        MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group)
        @exception_counts = 2
        Gibbon::API.any_instance.stub(:lists) do
          @exception_counts -= 1
          if @exception_counts <= 0
            raise Gibbon::MailChimpError
          else
            Gibbon::API.new
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
          Gibbon::API.any_instance.stub_chain(:lists, :batch_subscribe)
          MailchimpSynchronizer.any_instance.stub(:coefficient_group_valid?).and_return(true)
          MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group)
          @c = Contact.make
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
          Gibbon::API.any_instance.stub_chain(:lists, :batch_subscribe)
          MailchimpSynchronizer.any_instance.stub(:coefficient_group_valid?).and_return(true)
          MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group)
          @c = Contact.make
          @c.accounts << account
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
          Gibbon::API.any_instance.stub_chain(:lists, :batch_subscribe)
          MailchimpSynchronizer.any_instance.stub(:coefficient_group_valid?).and_return(true)
          MailchimpSynchronizer.any_instance.stub(:find_or_create_coefficients_group)
          Gibbon::API.any_instance.stub_chain(:lists, :segment_add).and_return({"id" => "1234"})
          @c = Contact.make(first_name: "Alex", last_name: "Halcon")
          @c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
          @c.accounts << account
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

  describe "#get_scope" do
    subject { sync.get_scope(true) }
    describe "when no segments" do
      it { should_not raise_exception }
    end
    context "when account does not have unlinked contacts" do
      before do
        c = Contact.make(first_name: "Hy Thuong", last_name: "Nguyen", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Samsung", last_name: "Galaxy", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Homer", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Lisa", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :former_student)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Bart", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Maggie", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Marge", last_name: "Simpson", owner_id: account.id)
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.coefficient_for_myaccname = "pmenos"
        c.save
        c = Contact.make(first_name: "Julieta", last_name: "Wertheimer", owner_id: account.id)
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
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Samsung", last_name: "Galaxy")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Homer", last_name: "Simpson")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c = Contact.make(first_name: "Bart", last_name: "Simpson")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Lisa", last_name: "Simpson")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :former_student)
        c.coefficient_for_myaccname = "perfil"
        c.save
        c = Contact.make(first_name: "Marge", last_name: "Simpson")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :prospect)
        c.coefficient_for_myaccname = "pmenos"
        c.save
        c = Contact.make(first_name: "Julieta", last_name: "Wertheimer")
        c.local_unique_attributes << LocalStatus.new(account_id: account.id, value: :student)
        c.coefficient_for_myaccname = "perfil"
        c.save
        # for some bizarre reason only onw unlink is not working, have to do it two times
        # only in this contact..
        c.unlink(account)
        c.unlink(account)
        c = Contact.make(first_name: "Maggie", last_name: "Simpson")
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
        account.contacts.count.should == 6
        sync.get_scope(true).count.should == 4
      end
    end
  end
  describe "#get_system_status" do
    subject { sync.get_system_status(contact) }
    describe "for contact with local_status :student" do
      let(:contact){ Contact.make(local_status_for_myaccname: :student) }
      it { should eq '|s||ps||sf|' }
    end
    describe "for contact with local_status 'student'" do
      let(:contact){ Contact.make(local_status_for_myaccname: "student") }
      it { should eq '|s||ps||sf|' }
    end
  end

  describe "#get_primary_attribute_value" do
    describe "if contact has none" do
      it "returns nil" do
        expect(sync.get_primary_attribute_value(contact,'Email')).to be_nil
      end
    end
    describe "if contact has" do
      let(:email_value){'dwa@sd.co'}
      before do
        contact.contact_attributes << Email.make(account: account, value: email_value)
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
      it "return ''" do
        expect(sync.get_coefficient_translation(contact)).to eq [{id: sync.coefficient_group, groups: [""]}]
      end
    end
  end

  describe "get_gender_translation" do
    describe "if contact's gender is not set" do
      before do
        contact.update_attribute :gender, nil
      end
      it "returns ''" do
        expect(sync.get_gender_translation(contact)).to eq ''
      end
    end
    describe "if contact's gender is mail" do
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
        resp = {
          "success_count"=>1, 
          "error_count"=>0, 
          "errors"=>[], 
          "data"=>[
            {
              "email"=>"pedro@gonzalez.com", 
              "list_id"=>"00000000", 
              "list_name"=>"development students 1", 
              "merges"=>{
                "EMAIL"=>"pedro@gonzalez.com", 
                "FNAME"=>"", 
                "LNAME"=>"", 
                "PHONE"=>"", 
                "GENDER"=>"", 
                "STATUS"=>"", 
                "ADDR"=>"", 
                "SYSSTATUS"=>"", 
                "SYSCOEFF"=>"", 
                "FOLLOWEDBY"=>"", 
                "GROUPINGS"=>[
                  {
                    "id"=>0000, 
                    "name"=>"Coefficient", 
                    "form_field"=>"hidden", 
                    "groups"=>[
                      {
                        "name"=>"unknown", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"perfil", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"pmas", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"pmenos", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"np", 
                        "interested"=>false
                      }
                    ]
                  }
                ]
              }, 
              "status"=>"subscribed", 
              "is_gmonkey"=>false, 
              "lists"=>[
                {
                  "id"=>"0000", 
                  "status"=>"subscribed"
                }
              ], 
              "geo"=>[], 
              "clients"=>[], 
              "static_segments"=>[], 
              "notes"=>[]
            }
          ]
        }
        Gibbon::API.any_instance.stub_chain(:lists, :member_info).and_return(resp)
      end
      it "should return true" do
        @ms.is_in_list?("mail@value.com").should be_truthy
      end
    end
    context "contact is unsubscribed or not in list" do
      before do
        @ms = MailchimpSynchronizer.new
        @ms.account = account
        @ms.save
        resp = {
          "success_count"=>1, 
          "error_count"=>0, 
          "errors"=>[], 
          "data"=>[
            {
              "email"=>"pedro@gonzalez.com", 
              "list_id"=>"00000000", 
              "list_name"=>"development students 1", 
              "merges"=>{
                "EMAIL"=>"pedro@gonzalez.com", 
                "FNAME"=>"", 
                "LNAME"=>"", 
                "PHONE"=>"", 
                "GENDER"=>"", 
                "STATUS"=>"", 
                "ADDR"=>"", 
                "SYSSTATUS"=>"", 
                "SYSCOEFF"=>"", 
                "FOLLOWEDBY"=>"", 
                "GROUPINGS"=>[
                  {
                    "id"=>0000, 
                    "name"=>"Coefficient", 
                    "form_field"=>"hidden", 
                    "groups"=>[
                      {
                        "name"=>"unknown", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"perfil", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"pmas", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"pmenos", 
                        "interested"=>false
                      }, 
                      {
                        "name"=>"np", 
                        "interested"=>false
                      }
                    ]
                  }
                ]
              }, 
              "status"=>"unsubscribed", 
              "is_gmonkey"=>false, 
              "lists"=>[
                {
                  "id"=>"0000", 
                  "status"=>"subscribed"
                }
              ], 
              "geo"=>[], 
              "clients"=>[], 
              "static_segments"=>[], 
              "notes"=>[]
            }
          ]
        }
        Gibbon::API.any_instance.stub_chain(:lists, :member_info).and_return(resp)
      end
      it "should return true" do
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
      Gibbon::API.any_instance.stub_chain(:lists, :interest_groupings).and_return([{"id" => "1234", "name" => "Coefficient"}])
      Gibbon::API.any_instance.stub_chain(:lists, :interest_grouping_add)
      @ms.stub(:email_admins_about_failure)
    end
    context "when coefficient group match" do
      before do
        @ms.coefficient_group = "1234"
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
        @ms.coefficient_group = "123234"
      end
      it "should be valid" do
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
      Gibbon::API.any_instance.stub_chain(:lists, :interest_groupings).and_return([{"id" => "1234", "name" => "Coefficient"}])
      Gibbon::API.any_instance.stub_chain(:lists, :interest_grouping_add).and_return({"id" => "4444"})
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
