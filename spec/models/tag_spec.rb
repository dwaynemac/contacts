# encoding: UTF-8
require 'spec_helper'

describe Tag do

  describe "#account_name" do
    let(:tag){Tag.make}
    it "returns tag.account.name" do
      expect(tag.account_name).to eq tag.account.name
    end
  end

  context "removing all tags with no contacts associated" do
    before do
      @first_account = Account.make()
      @secont_account = Account.make()
      @first_contact = Contact.make(owner: @first_account)
      @second_contact = Contact.make(owner: @secont_account)
      @first_tag = Tag.make(name: "first tag")
      @second_tag = Tag.make(name: "second tag")
      @third_tag = Tag.make(name: "third tag")      
    end
    describe "when no tags are linked to a contact" do
      it "should remove all tags" do
        expect{Tag.remove_all_empty}.to change{Tag.count}.from(3).to(0)
      end
    end

    describe "when tags are associated to different contacts with different accounts" do
      before do
        @first_contact.tags << @first_tag
        @second_contact.tags << @second_tag
      end
      it "should not delete tags that are linked to any contact fromany account" do
        expect{Tag.remove_all_empty}.to change{Tag.count}.from(3).to(2)
        Tag.find(@first_tag.id).should == @first_tag
        Tag.find(@second_tag.id).should == @second_tag
        expect{Tag.find(@third_tag.id)}.to raise_error
      end
    end

    describe "when all tags are associated to a contact" do
      before do
        @first_contact.tags << @first_tag
        @first_contact.tags << @third_tag
        @second_contact.tags << @second_tag
      end
      it "should not delete any tags" do
        expect{Tag.remove_all_empty}.not_to change{Tag.count}
      end
    end

    describe "when a tag had been associated to a contact, but is no more" do
      before do
        @first_contact.tags << @first_tag
        @first_contact.tags = []
        @first_contact.save
      end
      it "should delete that tag" do
        @first_tag.contacts.should == []
        expect{Tag.remove_all_empty}.to change{Tag.count}.from(3).to(0)
      end
    end
  end
  
  describe ".batch_add (with delay)" do
    it "queues delayed_job task" do
      expect{ Tag.batch_add([],[]) }.to change{Delayed::Job.count}.by(1)
    end
  end
  
  describe ".batch_add (without delay)" do
    before do
      @new_account = Account.make(name: "test_account")
      @first_tag = Tag.make(account_name: @new_account.name, name: "abril")
      @second_tag = Tag.make(account_name: @new_account.name, name: "mayo")
      @third_tag = Tag.make(account_name: @new_account.name, name: "junio")
      @first_contact = Contact.make(owner: @new_account)
      @second_contact = Contact.make(owner: @new_account)
    end
    context "when adding only existing tags to contacts that didnt have those tags" do
      before do
        Tag.batch_add_without_delay([@first_tag.id, @second_tag.id, @third_tag.id],
                      [@first_contact.id, @second_contact.id]
                     )
        @first_contact.save
        @second_contact.save
      end
      it "should update contacts with these tags" do
        @first_contact.reload.tags.should include(@first_tag, @second_tag, @third_tag)
        @second_contact.reload.tags.should include(@first_tag, @second_tag, @third_tag)
      end
      it "should not have repeated tags" do
        @first_contact.reload.tags.where(name: @first_tag.name).count.should == 1
      end
      it "should update the contact keywords" do
        @first_contact.reload._keywords.should include(@first_tag.name, @second_tag.name, @third_tag.name)
        @second_contact.reload._keywords.should include(@first_tag.name, @second_tag.name, @third_tag.name)
      end
    end

    context "when adding only existing tags to contacts that did have those tags" do
      before do
        @first_contact.tags << @first_tag
        @second_contact.tags << @third_tag
        Tag.batch_add_without_delay([@first_tag.id, @second_tag.id, @third_tag.id],
                      [@first_contact.id, @second_contact.id])
        @first_contact.reload
        @second_contact.reload
        @first_contact.save
        @second_contact.save
      end
      it "should update contacts with these tags" do
        @first_contact.reload.tags.should include(@first_tag, @second_tag, @third_tag)
        @second_contact.reload.tags.should include(@first_tag, @second_tag, @third_tag)
      end
      it "should not have repeated tags" do
        @first_contact.reload.tags.where(name: @first_tag.name).count.should == 1
      end
      it "should update the contact keywords" do
        @first_contact.reload._keywords.should include(@first_tag.name, @second_tag.name, @third_tag.name)
        @second_contact.reload._keywords.should include(@first_tag.name, @second_tag.name, @third_tag.name)
      end
    end
  end


end
