require 'spec_helper'

describe V0::AttachmentsController do
  # TODO: add :only option to matcher
  # it_should_behave_like "Secure API Controller", :only => :update

  before do
    @contact = Contact.make
    attach = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
    @contact.attachments << Attachment.new(
      :account => @contact.owner, 
      :category => :home, 
      :value => "value",
      :file => attach)
    @contact.save
    @contact.reload
  end


  describe "#update" do
    context "with app_key" do
      before do
        new_attach = fixture_file_upload('spec/support/robot3.jpg', 'image/jpg')
        put :update, :account_name => @contact.owner.name, :contact_id => @contact.id,
            :id => @contact.attachments.first.id, :contact_attributes => {:file => new_attach},
            :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :success }
      it "should change the value" do
        @contact.reload.attachments.first.file.url.should match /robot3\.jpg/
      end
    end
    context "without app_key" do
      before do
        put :update, :id => 1
      end
      it "should deny access" do
        should respond_with(401)
      end
    end
  end

  describe "#create" do
    context "called by contact owner" do
      context "sending :category, :value" do
        before do
          attach = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
          post :create, :account_name => @contact.owner.name, :contact_id => @contact.id,
               :contact_attributes => {:category => :home, :value => "New Attachment", :file => attach},
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new file" do
          @contact.reload.attachments.count.should == 2 #last.attachment.url.should match /ghibli_main_logo\.gif/
          @contact.reload.attachments.last.file.url.should match /ghibli_main_logo\.gif/
        end
        it "should assign attachment to account" do
          @contact.reload.attachments.last.account.should == @contact.owner
        end
      end  
    end
    context "called by un-linked account" do
      let(:other_account){Account.make}
      before do
        attach = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        post :create, :account_name => other_account.name, :contact_id => @contact.id,
             :contact_attributes => {
                :category => :home,
                :file => attach
             },
             :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :missing }
    end
    context "called by linked, non-owner account" do
      let(:other_account){Account.make}
      before do
        other_account.link(@contact)
        attach = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        post :create, :account_name => other_account.name, :contact_id => @contact.id,
             :contact_attributes => {
                :category => :home,
                :value => "New Attach",
                :file => attach
             },
             :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :created }
      it "should create a new attachment" do
        @contact.reload.attachments.last.file.url.should match /ghibli_main_logo\.gif/
      end
      it "should assign attribute to account" do
        @contact.reload.attachments.last.account.should == other_account
      end
    end
  end

  describe "#delete" do
    before do
      @attachment = @contact.attachments.first
    end
    describe "as the owner" do
      it "should delete a contact attribute" do
        expect{post :destroy, :method => :delete,
                    :id => @attachment.id,
                    :contact_id => @contact.id,
                    :account_name => @contact.owner.name,
                    :app_key => V0::ApplicationController::APP_KEY}.to change{@contact.reload.attachments.count}.by(-1)
      end
      it "should remove value from _keywords" do
        post :destroy, :method => :delete,
             :id => @attachment.id,
             :contact_id => @contact.id,
             :account_name => @contact.owner.name,
             :app_key => V0::ApplicationController::APP_KEY
        @contact.reload._keywords.should_not include(@attachment.value)
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
                    :id => @attachment.id,
                    :contact_id => @contact.id,
                    :account_name => @account.name,
                    :app_key => V0::ApplicationController::APP_KEY}.not_to change{@contact.reload.attachments.count}
      end
    end
  end
end