# encoding: UTF-8
require 'spec_helper'

describe Tag do

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
end