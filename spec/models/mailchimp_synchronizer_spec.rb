require 'spec_helper'

describe MailchimpSynchronizer do
  let(:account){Account.make(name: 'myaccname')}
  let(:sync){MailchimpSynchronizer.new(account: account)}
  let(:contact){Contact.make}


  describe "#subscribe_contacts" do
    before do
      contact.accounts << account
      sync.save
    end
    context "if mailchimp fails concistenly" do
      before do
        Gibbon::API.any_instance.stub(:lists).and_raise(Gibbon::MailChimpError)
      end
      it "re-raises Gibbon::MailChimpError" do
        expect{sync.subscribe_contacts_without_delay}.to raise_exception
      end
      it "sends email to padma admins" do
        expect {sync.subscribe_contacts_without_delay}.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end
    context "if mailchimp fails erratically" do
      before do
        @exception_counts = 2
        Gibbon::API.any_instance.stub(:lists) do
          @exception_counts -= 1
          if @exception_counts <= 0
            raise Gibbon::MailchimpError
          else
            Gibbon::API.new
          end
        end
      end
      it "catches Gibbon::MailChimpError and retries" do
        expect{sync.subscribe_contacts_without_delay}.not_to raise_exception
      end
    end
  end

  describe "#get_scope" do
    subject { sync.get_scope }
    describe "when no segments" do
      it { should_not raise_exception }
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
end
