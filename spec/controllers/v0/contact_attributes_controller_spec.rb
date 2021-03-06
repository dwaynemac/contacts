require 'spec_helper'

describe V0::ContactAttributesController do
  # TODO: add :only option to matcher
  # it_should_behave_like "Secure API Controller", :only => :update

  before do
    @contact = Contact.make(owner: Account.make)
    @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "12343210")
    @contact.save
    @contact.reload
  end

  describe "#custom_keys" do
    context "without app_key" do
      before do
        get :custom_keys
      end
      it "should deny access" do
        should respond_with(401)
      end
    end
    context "with app_key" do
      let(:contact){Contact.make(owner: Account.make)}
      before do
        contact.contact_attributes << ContactAttribute.make(_type: 'CustomAttribute', value: 'surf', name: 'hobby', account: contact.owner )
        contact.save!

        @contact.contact_attributes << ContactAttribute.make(_type: 'CustomAttribute', value: 'surf', name: 'sport', account: @contact.owner )
        @contact.save!
      end
      def do_request(params={})
        get :custom_keys, params.merge({app_key: V0::ApplicationController::APP_KEY})
      end
      let(:body){ActiveSupport::JSON.decode(response.body)}
      it "responds with 200" do
        do_request account_name: Account.make.name
        should respond_with 200
      end
      it "scopes to given account_name" do
        do_request(account_name: @contact.owner_name)
        body['total'].should == 1
        body['collection'].should include @contact.custom_attributes.last.name
      end
    end
  end

  describe "#update" do
    context "with app_key" do
      before do
        @new_value = "54321541"
        put :update, :account_name => @contact.owner_name, :contact_id => @contact.id,
            :id => @contact.contact_attributes.first.id, :contact_attribute => {:value => @new_value},
            :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :success }
      it "should change the value" do
        @contact.reload.contact_attributes.first.value.should == @new_value
      end
      it "should update contact _keywords" do
        @contact.reload._keywords.should include(@new_value)
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
          @telephone = "54321541"
          post :create, :account_name => @contact.owner.name, :contact_id => @contact.id,
               :contact_attribute => {:category => :home, :value => @telephone, '_type' => "Telephone"},
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new telephone" do
          @contact.reload.contact_attributes.last.value.should == @telephone
        end
        it "should assign attribute to account" do
          @contact.reload.contact_attributes.last.account.should == @contact.owner
        end
      end
      context "sending :year, :month, :day, :category" do
        before do
          post :create, :account_name => @contact.owner.name, :contact_id => @contact.id,
               :contact_attribute => {
                 '_type' => 'DateAttribute',
                 :value => 'basura',
                 :category => 'birth_date',
                 :year => '2010',
                 :month => '1',
                 :day => '1'},
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new date_attribute" do
          @contact.reload.contact_attributes.last.should be_a DateAttribute
          @contact.contact_attributes.last.date.should == Date.civil(2010,1,1)
        end
        it "should assign attribute to account" do
          @contact.reload.contact_attributes.last.account.should == @contact.owner
        end
      end
    end
    context "called by un-linked account" do
      let(:other_account){Account.make}
      before do
        @telephone = "54321541"
        post :create, :account_name => other_account.name, :contact_id => @contact.id,
             :contact_attribute => {
                :category => :home,
                :value => @telephone,
                '_type' => "Telephone"
             },
             :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :missing }
    end
    context "called by linked, non-owner account" do
      let(:other_account){Account.make}
      before do
        other_account.link(@contact)
        @telephone = "54321541"
        post :create, :account_name => other_account.name, :contact_id => @contact.id,
             :contact_attribute => {
                :category => :home,
                :value => @telephone,
                '_type' => "Telephone"
             },
             :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :created }
      it "should create a new telephone" do
        @contact.reload.contact_attributes.last.value.should == @telephone
      end
      it "should assign attribute to account" do
        @contact.reload.contact_attributes.last.account.should == other_account
      end
      it "should update contact _keywords" do
        @contact.reload._keywords.should include(@telephone)
      end
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
      it "should remove value from _keywords" do
        post :destroy, :method => :delete,
             :id => @contact_attribute.id,
             :contact_id => @contact.id,
             :account_name => @contact.owner.name,
             :app_key => V0::ApplicationController::APP_KEY
        @contact.reload._keywords.should_not include(@contact_attribute.value)
      end
    end
    describe "as a viewer/editor" do
      before do
        @account = Account.make
        @account.link @contact
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
