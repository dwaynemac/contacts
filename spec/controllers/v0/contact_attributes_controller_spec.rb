require 'spec_helper'

describe V0::ContactAttributesController do
  # TODO: add :only option to matcher
  # it_should_behave_like "Secure API Controller", :only => :update

  before do
    @contact = Contact.make
    @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "1234321")
    @contact.save
    @contact.reload
  end

  describe "#update" do
    context "with app_key" do
      before do
        @new_value = "5432154"
        put :update, :account_name => @contact.owner.name, :contact_id => @contact.id,
            :id => @contact.contact_attributes.first.id, :contact_attribute => {:value => @new_value},
            :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :success }
      it "should change the value" do
        @contact.reload.contact_attributes.first.value.should == @new_value
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
    before do
      @telephone = "5432154"
      post :create, :account_name => @contact.owner.name, :contact_id => @contact.id, :contact_attribute => {:category => :home, :value => @telephone},
                  :app_key => V0::ApplicationController::APP_KEY
    end
    it { should respond_with :created }
    it "should create a new telephone" do
      @contact.reload.contact_attributes.last.value.should == @telephone
    end
  end

  describe "#delete" do
    before do
      @contact_attribute = @contact.contact_attributes.first
    end
    describe "as the owner" do
      it "should delete a contact attribute" do
        expect{post :destroy, :method => :delete,
                    :id => @contact_attribute.id,
                    :contact_id => @contact.id,
                    :account_name => @contact.owner.name,
                    :app_key => V0::ApplicationController::APP_KEY}.to change{@contact.reload.contact_attributes.count}.by(-1)
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
                    :id => @contact_attribute.id,
                    :contact_id => @contact.id,
                    :account_name => @account.name,
                    :app_key => V0::ApplicationController::APP_KEY}.not_to change{@contact.reload.contact_attributes.count}
      end
    end
  end
end
