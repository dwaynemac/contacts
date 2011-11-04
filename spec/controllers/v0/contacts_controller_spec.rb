require 'spec_helper'

describe V0::ContactsController do
  it_should_behave_like "Secure API Controller"

  before(:each) do
    2.times do
      Contact.make
    end
  end

  describe "#index" do
    context "without params" do
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
    context "specifying valid account and list_name" do
      before do
        account_a = Account.make(:name => "a")
        account_b = Account.make(:name => "b")

        3.times do
          account_a.lists.first.contacts << Contact.make
        end

        @contact_b = Contact.make
        account_b.lists.first.contacts << @contact_b

        l = List.make(:account => account_a )
        @contact_l = Contact.make
        l.contacts << @contact_l

        get :index, {:account_name => "a", :list_name => "a", :app_key => V0::ApplicationController::APP_KEY}
      end
      it { should respond_with(:success)}
      it { should assign_to(:contacts) }
      it "should return contacts of specified account and list" do
        assigns(:contacts).size.should == 3
      end
      it "should not include contacts of account b" do
        assigns(:contacts).should_not include(@contact_b)
      end
      it "should not include contacts of account a but of other lists" do
        assigns(:contacts).should_not include(@contact_l)
      end
    end
    context "specifying valid account with unexisting list_name" do
      before do
        Account.make(:name => "a")
        get :index, {:account_name => "a", :list_name => "blah", :app_key => V0::ApplicationController::APP_KEY}
      end
      it { should respond_with(:not_found)}
    end
  end

  describe "#show" do
    before(:each) do
      @contact = Contact.first
      @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "1234321")
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

    describe "when scoped to an account that doesn't own the contact" do
      before(:each) do
        @contact2 = Contact.make(:owner => @contact.owner)
        @contact2.contact_attributes << ContactAttribute.make(:account => @contact.owner, :public => true)
        @contact2.contact_attributes << ContactAttribute.make(:account => @contact.owner, :public => false)

        get :show, :id => @contact2.id, :account_name => Account.make.name, :app_key => V0::ApplicationController::APP_KEY
      end

      it "should show only public contact attributes" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:contact_attributes].count.should equal(1)
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

  describe "#update from Typhoeus" do
    before do
      @contact = Contact.first
      @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "1234321")
      @contact.save
      @new_first_name = "Homer"
      put :update, :id => @contact.id, "contact"=>{"contact_attributes_attributes"=>["{\"_id\"=>\"#{@contact.contact_attributes.first._id}\", \"type\"=>\"Telephone\", \"category\"=>\"home\", \"value\"=>\"12345\", \"public\"=>1}"], "_id" => @contact.id, "first_name"=>@new_first_name},
                  :app_key => V0::ApplicationController::APP_KEY
    end
    it "should change first name" do
      @contact.reload.first_name.should == @new_first_name
    end

    it "should change telephone value" do
      @contact.reload.contact_attributes.first.value.should == "12345"
    end
  end

  describe "#create" do
    it "should create a contact" do
      expect{post :create,
                  :contact => Contact.plan,
                  :app_key => V0::ApplicationController::APP_KEY}.to change{Contact.count}.by(1)
    end

    describe "should create a contact with attributes" do
      before do
        post :create,
                  :contact => Contact.plan(:contact_attributes => [ContactAttribute.plan]),
                  :app_key => V0::ApplicationController::APP_KEY
      end
      it { assigns(:contact).should_not be_new_record }
      it { assigns(:contact).contact_attributes.should have_at_least(1).attribute }
      it { assigns(:contact).contact_attributes.first.should_not be_new_record }
    end

    describe "should create a contact with attributes (Typhoeus)" do
      before do
        post :create,
                  "contact"=>{"contact_attributes_attributes"=>["{\"_type\"=>\"Telephone\", \"public\"=>nil, \"category\"=>\"f\", \"value\"=>\"1112312\"}", "{\"_type\"=>\"Email\", \"public\"=>nil, \"category\"=>\"d\", \"value\"=>\"lionel.hutz75@hotmail.com\"}"], "first_name"=>"Lionel", "last_name"=>"Hutz"},
                  :app_key => V0::ApplicationController::APP_KEY
      end
      it { assigns(:contact).should_not be_new_record }
      it { assigns(:contact).contact_attributes.should have_at_least(1).attribute }
      it { assigns(:contact).contact_attributes.first.should_not be_new_record }
    end

    it "should respect model validations" do
      expect{post :create,
                  :contact => Contact.plan(:first_name => ""),
                  :app_key => V0::ApplicationController::APP_KEY }.not_to change{Contact.count}
    end

    describe "when scoped to an account" do
      before(:each) do
        @account = Account.make
        post :create,
             :account_name => @account.name,
             :contact => Contact.plan(:owner => nil),
             :app_key => V0::ApplicationController::APP_KEY
      end

      it "should set the owner if scoped to an account" do
        Contact.last.owner.should == @account
      end
      it "should set the default list if scoped to an account" do
        @account.lists.first.contacts.should include(assigns(:contact))
      end
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
