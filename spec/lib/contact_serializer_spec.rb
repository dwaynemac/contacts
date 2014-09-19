require 'spec_helper'

describe ContactSerializer do

  let(:account){Account.make}
  let(:serializer){ContactSerializer.new(mode: mode, contact: contact, account: account)}
  let(:serialized_keys){serializer.serialize.keys}
  let(:contact){Contact.make()}

  describe "with mode: 'all'" do
    let(:mode){ 'all' }
    describe "with account" do
      let(:account){Account.make}
      before do
        serializer.account = account
      end
      describe "#serialize" do
        it "includes all contact_attributes" do
          contact.contact_attributes << Telephone.new( value: 1234 , account: account)
          contact.save!
          contact.reload.contact_attributes.count.should == 1
          serializer.serialize['contact_attributes'].count.should == 1
        end
        it "render :id as a String" do
          expect(serializer.serialize['id']).to be_a String
          expect(serializer.serialize['id']).not_to be_a BSON::ObjectId
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

  describe "local attribute last_seen_at" do
    let(:mode){ 'select' }
    let(:select){ ['last_seen_at'] }
    before do
      contact.local_unique_attributes << LastSeenAt.new(value: 1.month.ago.to_time,
                                                        account: account)
      serializer.select = select
    end
    it "is serialized as a string" do
      expect(serializer.serialize['last_seen_at']).to be_a String
    end
  end

end
