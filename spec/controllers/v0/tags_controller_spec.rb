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
          post :create, :account_name => @contact.owner.name, :contact_id => @contact.id,
               :tag => { :name => "comple", :account_name => @contact.owner.name },
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new tag" do
          @contact.reload.tags.count.should == 1
          @contact.reload.tags.last.name.should == "comple"
          @account.reload.tags.count.should == 1
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
          @account.reload.tags.last.should == "febrero"
        end
        it "should assign tag to account" do
          @account.reload.tags.last.account.should == @contact.owner
        end
        it "should'n be assigned to contact" do
          @account.reload.tags.last.contacts.should be_empty
        end
      end
    end

    context "called by another account" do
      let(:other_account){Account.make}
      before do
        post :create, :account_name => other_account.name, :contact_id => @contact.id,
             :tag => { :name => "profu", :account_name => other_account.name },
             :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :missing }
    end
    context "called by linked, non-owner account" do
      let(:other_account){Account.make}
      before do
        other_account.link(@contact)
        post :create, :account_name => other_account.name, :contact_id => @contact.id,
             :tag => { :name => "exalumno", :account_name => other_account.name },
             :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :created }
      it "should create a new attachment" do
        @contact.reload.tags.last.should == "exalumno"
      end
      it "should assign attribute to account" do
        @contact.reload.tags.last.account.should == other_account
      end
    end
  end

  describe "#delete" do
    before do
      @tag = @contact.tags.create(name: "marzo")
    end
    describe "as the owner" do
      it "should delete a contact attribute" do
        expect{post :destroy, :method => :delete,
                    :id => @tag.id,
                    :contact_id => @contact.id,
                    :account_name => @contact.owner.name,
                    :app_key => V0::ApplicationController::APP_KEY}.to change{@contact.reload.tags.count}.by(-1)
      end
      it "should remove name from _keywords" do
        post :destroy, :method => :delete,
             :id => @tag.id,
             :contact_id => @contact.id,
             :account_name => @contact.owner.name,
             :app_key => V0::ApplicationController::APP_KEY
        @contact.reload._keywords.should_not include(@tag.name)
      end
    end
    describe "as a viewer/editor" do
      before do
        @account = Account.make
        @account.lists.first.contacts << @contact
        @account.save
      end
      it "should not delete the contact attribute" do
        expect{post :destroy, :method => :delete,
                    :id => @tag.id,
                    :contact_id => @contact.id,
                    :account_name => @account.name,
                    :app_key => V0::ApplicationController::APP_KEY}.not_to change{@contact.reload.tags.count}
      end
    end
  end
end