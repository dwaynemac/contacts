require 'spec_helper'

describe V0::TagsController do

  before do
    @account = Account.make
    @contact = Contact.make(:owner => @account)
    @contact.save
    @contact.reload
  end


  describe "#create" do
    context "called by contact" do
      context "sending :name" do
        before do
          post :create, :account_name => @contact.owner.name, :contact_ids => @contact.id,
               :tag => { :name => "complementacion" },
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new tag" do
          @contact.reload.tags.count.should == 1
          @contact.reload.tags.last.name.should == "complementacion"
          @account.reload.tags.count.should == 1
        end
        it "should be included in the contacts keywords" do
          @contact.reload._keywords.should include("complementacion")
        end
        it "should assign tag to account" do
          @contact.reload.tags.last.account.should == @contact.owner
        end
      end  
    end

    context "called by account" do
      context "sending :name" do
        before do
          post :create, :account_name => @contact.owner.name,
               :tag => { :name => "febrero", :account_name => @contact.owner.name },
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new tag" do
          @account.reload.tags.count.should == 1
          @account.reload.tags.last.name.should == "febrero"
        end
        it "should assign tag to account" do
          @account.reload.tags.last.account.should == @contact.owner
        end
        it "should'n be assigned to contact" do
          @account.reload.tags.last.contacts.should be_empty
        end
      end

      context "sending :name with empty contact_ids" do
        before do
          post :create, :account_name => @contact.owner.name, :contact_ids => "",
               :tag => { :name => "febrero"},
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new tag" do
          @account.reload.tags.count.should == 1
          @account.reload.tags.last.name.should == "febrero"
        end
        it "should assign tag to account" do
          @account.reload.tags.last.account.should == @contact.owner
        end
        it "should'n be assigned to contact" do
          @account.reload.tags.last.contacts.should be_empty
        end
      end
    end

    context "called by linked, non-owner account" do
      let(:other_account){Account.make}
      before do
        other_account.link(@contact)
        post :create, :account_name => other_account.name, :contact_ids => @contact.id,
             :tag => { :name => "exalumno", :account_name => other_account.name },
             :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :created }
      it "should create a new attachment" do
        @contact.reload.tags.last.name.should == "exalumno"
      end
      it "should assign attribute to account" do
        @contact.reload.tags.last.account.should == other_account
      end
    end
  end

  describe "#update" do
    before do
      @new_account = Account.make
      @new_contact = Contact.make(owner: @new_account)
      @another_contact = Contact.make(owner: @new_account)
      @new_tag = Tag.make(account_id: @new_account.id)
      @new_contact.tags << @new_tag
      @another_contact.tags << @new_tag
    end
    it "should have its contact list correct before updated" do
      @new_tag.contact_ids.should include(@new_contact.id, @another_contact.id)
    end
    context "when the contact list has been updated" do
      before do
        put :update, :account_name => @new_account.name, :contact_ids => [@another_contact.id],
            :id => @new_tag.id,
            :app_key => V0::ApplicationController::APP_KEY
      end
      it "should update its contact list" do
        @new_tag.reload.contact_ids.count.should == 1
        @new_tag.contact_ids.should_not include(@new_contact.id)
        @new_tag.contact_ids.should include(@another_contact.id)
      end
    end
    context "if the contact list is empty" do
      before do
        put :update, :account_name => @new_account.name,
            :id => @new_tag.id,
            :app_key => V0::ApplicationController::APP_KEY
      end
      it "should remove all associated contacts" do
        @new_tag.reload.contact_ids.count.should == 0
        @new_tag.contact_ids.should_not include(@new_contact.id, @another_contact.id)
      end
      it "should remove the tag name from the contacts keywords" do
        @new_contact._keywords.should_not include(@new_tag.name)
      end
      it "should not remove contacts from database" do
        Contact.find(@new_contact.id).should_not be_nil
      end
    end
  end

  describe "#batch_add" do
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
        post :batch_add, :account_name => @new_account.name,
        :tags => [@first_tag.id, @second_tag.id, @third_tag.id],
        :contact_ids => [@first_contact.id, @second_contact.id],
        :app_key => V0::ApplicationController::APP_KEY
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
        post :batch_add, :account_name => @new_account.name,
        :tags => [@first_tag.id, @second_tag.id, @third_tag.id],
        :contact_ids => [@first_contact.id, @second_contact.id],
        :app_key => V0::ApplicationController::APP_KEY
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

  describe "#delete" do
    before do
      @tag = @contact.tags.create(name: "marzo", account_id: @contact.owner.id)
    end
    describe "as the owner" do
      it "should delete a contact attribute" do
        expect{delete :destroy,
                    :id => @tag.id,
                    :contact_id => @contact.id,
                    :account_name => @contact.owner.name,
                    :app_key => V0::ApplicationController::APP_KEY}.to change{@contact.reload.tags.count}.by(-1)
      end
      it "should remove name from _keywords" do
        delete :destroy,
             :id => @tag.id,
             :contact_id => @contact.id,
             :account_name => @contact.owner.name,
             :app_key => V0::ApplicationController::APP_KEY
        @contact.reload._keywords.should_not include(@tag.name)
      end
    end
    describe "as a viewer/editor" do
      before do
        @another_account = Account.make
        @another_account.lists.first.contacts << @contact
        @another_account.save
      end
      it "should not delete the tag" do
        expect{delete :destroy,
                    :id => @tag.id,
                    :contact_id => @contact.id,
                    :account_name => @another_account.name,
                    :app_key => V0::ApplicationController::APP_KEY}.not_to change{@contact.reload.tags.count}
      end
    end
  end
end