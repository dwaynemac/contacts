# encoding: UTF-8
require 'ar_spec_helper'

describe ContactSerializer do

  let(:account){NewAccount.make}
  let(:serializer){NewContactSerializer.new(mode: mode, contact: contact, account: account)}
  let(:serialized_keys){serializer.serialize.keys}
  let(:contact){NewContact.make(owner: account)}

  describe "with mode: 'all'" do
    let(:mode){ 'all' }
    describe "with account" do
      before do
        serializer.account = account
      end
      describe "#serialize" do
        before do
          contact.first_enrolled_on = Date.today
        end
        it "includes all contact_attributes" do
          NewTelephone.make(:contact_id => contact.id, value: '12341234', account: account)
          contact.contact_attributes.count.should == 1
          serializer.serialize['contact_attributes'].count.should == 1
        end
        it "render :id as a String" do
          expect(serializer.serialize['id']).to be_a String
          expect(serializer.serialize['id']).not_to be_a BSON::ObjectId
        end
        it "renders :first_enrolled_on as String" do
          expect(serializer.serialize['first_enrolled_on']).to be_a String
        end
      end
    end
  end

  describe "with mode: 'select'" do
    let(:mode){ 'select' }
    describe "with select: ['avatar']" do
      before do
        #given that contact has an avatar
        contact.avatar = File.open('spec/support/ghibli_main_logo.gif')

        #select avatar
        serializer.select = ['avatar'] 
      end
      describe "#serialize" do
        it "includes :avatar" do
          ( 'avatar' ).should be_in serialized_keys
        end
      end
    end
  end

  describe "with mode: 'only_name'" do
    let(:mode){ 'only_name' }
    describe "#serialize" do
      it "returns :id, :name" do
        serialized_keys.should == %W(id name)
      end
    end
  end

  describe "selecting local_statuses" do
    let(:other_account){ NewAccount.make }
    let(:mode){ 'select' }
    let(:select){ ['local_statuses'] }
    before do
      contact.account_contacts.find_or_create_by_account_id(account_id: account.id).update_attribute(:local_status, 'student')
      contact.account_contacts.find_or_create_by_account_id(account_id: other_account.id).update_attribute(:local_status, 'former_student')
      serializer.select = select
    end 
    it "serializes an array of hashes with keys :account, :local_status" do
      expect(serializer.serialize['local_statuses']).to eq [
        { 'account_name' => account.name, 'local_status' => 'student' },
        { 'account_name' => other_account.name, 'local_status' => 'former_student' }
      ]
    end
  end

  describe "local attribute last_seen_at" do
    let(:mode){ 'select' }
    let(:select){ ['last_seen_at'] }
    before do
      contact.account_contacts.find_or_create_by_account_id(account_id: account.id).update_attribute(:last_seen_at, 1.month.ago.to_time)
      serializer.select = select
    end
    it "is serialized as a string" do
      expect(serializer.serialize['last_seen_at']).to be_a String
    end
  end

end
