require 'spec_helper'

describe V0::ContactsController do
  it_should_behave_like "Secure API Controller"

  before(:each) do
    2.times do
      Contact.make
    end
  end

  describe "#index" do
    before do
      get :index, :app_key => V0::ApplicationController::APP_KEY
    end
    it { should respond_with(:success) } # response.should be_success
    it { should assign_to(:contacts) }
    it "should show total amount of contacts" do
      result = ActiveSupport::JSON.decode(response.body)
      result["total"].should == 2
    end
  end

  describe "#show" do
    before(:each) do
      @contact = Contact.first
      @contact.contact_attributes << ContactAttribute.make(:account => @contact.owner)
      @contact.contact_attributes << ContactAttribute.make(:account => Account.make, :public => true)
      @contact.contact_attributes << ContactAttribute.make(:account => Account.make, :public => false)
      @contact.save
    end
    describe "when unscoped" do
      before(:each) do
        get :show, :id => @contact.id, :app_key => V0::ApplicationController::APP_KEY
      end

      it { should respond_with(:success) }
      it { should assign_to(:contact) }

      it "should include all the contact_attributes" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:contact_attributes].count.should equal(3)
      end
    end

    describe "when scoped to an account" do
      before(:each) do
        get :show, :id => @contact.id, :account_name => @contact.owner.name, :app_key => V0::ApplicationController::APP_KEY
      end
      it "should include only the contact_attributes visible to that account" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:contact_attributes].count.should equal(2)
      end
    end
  end

  describe "#update" do
    before do
      @contact = Contact.first
      @new_first_name = "Homer"
      put :update, :id => @contact.id, :contact => {:first_name => @new_first_name},
                  :app_key => V0::ApplicationController::APP_KEY
    end
    it "should change first name" do
      @contact.reload.first_name.should == @new_first_name
    end
  end

  describe "#create" do
    it "should create a contact" do
      expect{post :create,
                  :contact => Contact.plan,
                  :app_key => V0::ApplicationController::APP_KEY}.to change{Contact.count}.by(1)
    end
    it "should respect model validations" do
      expect{post :create,
                  :contact => Contact.plan(:first_name => ""),
                  :app_key => V0::ApplicationController::APP_KEY }.not_to change{Contact.count}
    end
    it "should set the owner if scoped to an account" do
      account = Account.make
      post :create,
           :account_name => account.name,
           :contact => Contact.plan(:owner => nil),
           :app_key => V0::ApplicationController::APP_KEY

      Contact.last.owner.should == account
    end
    it "should set the default list if scoped to an account" do
      account = Account.make
      post :create,
           :account_name => account.name,
           :contact => Contact.plan(:owner => nil),
           :app_key => V0::ApplicationController::APP_KEY

      account.reload.lists.first.contacts.include? assigns(:contact)
    end
    it "should not set the owner if not scoped to an account" do
      post :create,
           :contact => Contact.plan(:owner => nil),
           :app_key => V0::ApplicationController::APP_KEY

      Contact.last.owner.should be_nil
    end
  end

  describe "#delete" do
    before do
      @contact = Contact.first
    end
    describe "as the owner" do
      it "should delete a contact" do
        expect{post :destroy, :method => :delete,
                    :id => @contact.id,
                    :account_name => @contact.owner.name,
                    :app_key => V0::ApplicationController::APP_KEY}.to change{Contact.count}.by(-1)
      end
    end
    describe "as a viewer/editor" do
      it "should not delete the contact" do
        expect{post :destroy, :method => :delete,
                    :id => @contact.id,
                    :app_key => V0::ApplicationController::APP_KEY}.not_to change{Contact.count}
      end
    end
  end

end
