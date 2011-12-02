require 'spec_helper'

describe V0::ContactAttributesController do
  # TODO: add :only option to matcher
  # it_should_behave_like "Secure API Controller", :only => :update
  describe "#update" do
    before do
      post :update, :id => 1
    end
    it "should deny access without app_key" do
      should respond_with(401)
    end
  end

  before do
    @contact = Contact.make
    @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "1234321")
    @contact.save
  end

  describe "#update" do
    before do
      @contact = Contact.first
      @new_value = "54321"
      put :update, :account_name => @contact.owner.name, :contact_id => @contact.id, :id => @contact.contact_attributes.first.id, :contact_attribute => {:value => @new_value},
                  :app_key => V0::ApplicationController::APP_KEY
    end
    it { should respond_with :success }
    it "should change the value" do
      @contact.reload.contact_attributes.first.value.should == @new_value
    end
  end

  describe "#create" do
    before do
      @contact = Contact.first
      @telephone = "54321"
      post :create, :account_name => @contact.owner.name, :contact_id => @contact.id, :contact_attribute => {:category => :home, :value => @telephone},
                  :app_key => V0::ApplicationController::APP_KEY
    end
    it { should respond_with :created }
    it "should create a new telephone" do
      @contact.reload.contact_attributes.last.value.should == @telephone
    end
  end
end
