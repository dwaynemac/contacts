# encoding: utf-8
require 'spec_helper'

describe V0::ContactsController do
  it_should_behave_like "Secure API Controller"
  it_should_behave_like 'Localized API'

  before(:each) do
    2.times do
      Contact.make
    end
  end

  
  describe "#index" do
    describe "paginates" do
      before do
        9.times { Contact.make }
        @isp = Contact.make(name: "in_second_page")
      end
      it "should return page 1" do
        get :index, :app_key => V0::ApplicationController::APP_KEY, :page => 1
        ActiveSupport::JSON.decode(response.body)["total"].should == Contact.count
        assigns(:contacts).should_not include(@isp)
      end
      it "should return page 2" do
        get :index, :app_key => V0::ApplicationController::APP_KEY, :page => 2
        ActiveSupport::JSON.decode(response.body)["total"].should == Contact.count
        assigns(:contacts).should include(@isp)
      end
    end
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
      it "should not include contact_attributes of account b" do
        @response.body
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

    describe "searches. Called with" do
      before do
        account = Account.make

        @first_name = Contact.make(first_name: "dwayne")
        @first_name.contact_attributes << Telephone.new(account_id: account._id, value: "1234")
        @first_name.save

        @email = Contact.make(last_name: "mac")
        @email.contact_attributes << Email.new(account_id: account._id, value: "other@mail.com")
        @email.contact_attributes << Email.new(account_id: account._id, value: "dwaynemac@gmail.com")
        @email.save

        @last_name = Contact.make(first_name: "asdf", last_name: "dwayne")
      end

      context ":ids" do
        before do
          get :index, :app_key => V0::ApplicationController::APP_KEY, :ids => [@first_name.id,@email.id]
        end
        it "should only include contacts specified by ids" do
          assigns(:contacts).should include(@first_name)
          assigns(:contacts).should include(@email)
          assigns(:contacts).should_not include(@last_name)
        end
      end

      context ":full_text it will make a full text search" do
        before do
          get :index, :app_key => V0::ApplicationController::APP_KEY, :full_text => "dwayne"
        end
        specify { assigns(:contacts).size.should == 3 }
        specify "within first_names" do
          assigns(:contacts).should include(@first_name)
        end
        specify "within last_names" do
          assigns(:contacts).should include(@last_name)
        end
        specify "within emails" do
          assigns(:contacts).should include(@email)
        end
      end

      context "When full_text contains various words it should match all of them" do
        before do
          @goku_contact = Contact.make(first_name: "Son", last_name: "Goku")
          @gohan_contact = Contact.make(first_name: "Son", last_name: "Gohan")

          get :index, :app_key => V0::ApplicationController::APP_KEY, :full_text => "Son Gok"
        end
        it "should match all words" do
          assigns(:contacts).should include(@goku_contact)
          assigns(:contacts).should_not include(@gohan_contact)
        end
      end

      context "with blank :full_text" do
        before do
          get :index, :app_key => V0::ApplicationController::APP_KEY, :full_text => ""
        end
        it { should respond_with(:success) } # response.should be_success
        it { should assign_to(:contacts) }
        it "should show total amount of contacts" do
          result = ActiveSupport::JSON.decode(response.body)
          result["total"].should == 5
        end
      end

      context ":where => " do
        before do
          @diff_mail = Contact.make(:first_name => "ale")
          @diff_mail.contact_attributes << Email.make(:value => "asdfasdf@asdf.com")

          @regex = Contact.make(:first_name => "Alejandro")
          @regex.contact_attributes << Email.make(:value => "dwanardo@lepes.com")
          @regex.save

          @w_phone = Contact.make(:first_name => "Aleman")
          @w_phone.contact_attributes << Email.make(:value => "dwalico@mail.com")
          @w_phone.contact_attributes << Telephone.make(:value => "12341234")
        end

        context "{:email => 'dwa', :first_name => 'Ale'}" do
          before do
            get :index, :app_key => V0::ApplicationController::APP_KEY,
                :where => {:email => "dwa", :first_name => "Ale"}
          end
          it "should build Criteria" do
            assigns(:contacts).selector.should == {
              "first_name" => /Ale/i,
              contact_attributes: { '$elemMatch' => { "_type" => "Email", "value" => /dwa/i}}
              }
          end
          it "should return contacts that match ALL conditions." do
            assigns(:contacts).should include(@regex)
          end
          it "should not return contacts that match only some of the conditions" do
            assigns(:contacts).should_not include(@diff_mail)
          end
          it "should considers conditions as regex" do
            assigns(:contacts).should include(@regex)
          end
        end

        context "{:email => 'dwa', :first_name => 'Ale', :telephone => '1234'}" do
          before do
            get :index, :app_key => V0::ApplicationController::APP_KEY,
                :where => {:email => "dwa", :first_name => "Ale", :telephone => "1234"}
          end
          it { assigns(:contacts).count.should == 1}
          it "should return contacts that match ALL conditions." do
            assigns(:contacts).should include(@w_phone)
          end
          it "should not return contacts that match only some of the conditions" do
            assigns(:contacts).should_not include(@regex)
            assigns(:contacts).should_not include(@diff_mail)
          end
        end

        context "{ :value => 'salti'}" do
          before do
            @addressed = Contact.make
            @addressed.contact_attributes << Address.make(:value => "saltin 23")
            @addressed.save

            get :index, :app_key => V0::ApplicationController::APP_KEY,
                        :where => { :contact_attributes => {:value => "salti"} }
          end
          it "should match street" do
            assigns(:contacts).to_a.should include(@addressed)
          end
          it "should match city"
        end
      end
    end
  end

  describe "#search" do
    describe "paginates" do
      before do
        9.times { Contact.make }
        @isp = Contact.make(name: "in_second_page")
      end
      it "should return page 1" do
        post :search, :app_key => V0::ApplicationController::APP_KEY, :page => 1
        ActiveSupport::JSON.decode(response.body)["total"].should == Contact.count
        assigns(:contacts).should_not include(@isp)
      end
      it "should return page 2" do
        post :search, :app_key => V0::ApplicationController::APP_KEY, :page => 2
        ActiveSupport::JSON.decode(response.body)["total"].should == Contact.count
        assigns(:contacts).should include(@isp)
      end
    end
    context "without params" do
      before do
        post :search, :app_key => V0::ApplicationController::APP_KEY
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

        post :search, {:account_name => "a", :list_name => "a", :app_key => V0::ApplicationController::APP_KEY}
      end
      it { should respond_with(:success)}
      it { should assign_to(:contacts) }
      it "should return contacts of specified account and list" do
        assigns(:contacts).size.should == 3
      end
      it "should not include contacts of account b" do
        assigns(:contacts).should_not include(@contact_b)
      end
      it "should not include contact_attributes of account b" do
        @response.body
      end
      it "should not include contacts of account a but of other lists" do
        assigns(:contacts).should_not include(@contact_l)
      end
    end

    context "specifying valid account with unexisting list_name" do
      before do
        Account.make(:name => "a")
        post :search, {:account_name => "a", :list_name => "blah", :app_key => V0::ApplicationController::APP_KEY}
      end
      it { should respond_with(:not_found)}
    end

    describe "searches. Called with" do
      before do
        account = Account.make

        @first_name = Contact.make(first_name: "dwayne")
        @first_name.contact_attributes << Telephone.new(account_id: account._id, value: "1234")
        @first_name.save

        @email = Contact.make(last_name: "mac")
        @email.contact_attributes << Email.new(account_id: account._id, value: "other@mail.com")
        @email.contact_attributes << Email.new(account_id: account._id, value: "dwaynemac@gmail.com")
        @email.save

        @last_name = Contact.make(first_name: "asdf", last_name: "dwayne")
      end

      context ":attribute_values_at" do
        before do

          HistoryEntry.create(attribute: 'level', old_value: 2, changed_at: Date.civil(2013,1,1).to_time, historiable: @first_name)

          post :search,
               app_key: V0::ApplicationController::APP_KEY,
               attribute_values_at: [
                   {
                       attribute: 'level',
                       value: 'yôgin',
                       ref_date: Date.civil(2012,12,31)
                   }
               ]
        end
        specify {HistoryEntry.value_at(:level, Date.civil(2012,12,31), class: 'Contact', id: @email.id).should_not == 2}
        specify { HistoryEntry.value_at(:level, Date.civil(2012,12,31), class: 'Contact', id: @first_name.id).should == 2 }
        it "should only include contacts that had given attributes at given dates" do
          assigns(:contacts).should include(@first_name)
          assigns(:contacts).should_not include(@email)
        end
      end

      context ":ids" do
        before do
          post :search, :app_key => V0::ApplicationController::APP_KEY, :ids => [@first_name.id,@email.id]
        end
        it "should only include contacts specified by ids" do
          assigns(:contacts).should include(@first_name)
          assigns(:contacts).should include(@email)
          assigns(:contacts).should_not include(@last_name)
        end
      end

      context ":full_text it will make a full text search" do
        before do
          post :search, :app_key => V0::ApplicationController::APP_KEY, :full_text => "dwayne"
        end
        specify { assigns(:contacts).size.should == 3 }
        specify "within first_names" do
          assigns(:contacts).should include(@first_name)
        end
        specify "within last_names" do
          assigns(:contacts).should include(@last_name)
        end
        specify "within emails" do
          assigns(:contacts).should include(@email)
        end
      end

      context "When full_text contains various words it should match all of them" do
        before do
          @goku_contact = Contact.make(first_name: "Son", last_name: "Goku")
          @gohan_contact = Contact.make(first_name: "Son", last_name: "Gohan")

          post :search, :app_key => V0::ApplicationController::APP_KEY, :full_text => "Son Gok"
        end
        it "should match all words" do
          assigns(:contacts).should include(@goku_contact)
          assigns(:contacts).should_not include(@gohan_contact)
        end
      end

      context "with blank :full_text" do
        before do
          post :search, :app_key => V0::ApplicationController::APP_KEY, :full_text => ""
        end
        it { should respond_with(:success) } # response.should be_success
        it { should assign_to(:contacts) }
        it "should show total amount of contacts" do
          result = ActiveSupport::JSON.decode(response.body)
          result["total"].should == 5
        end
      end

      context ":where => " do
        before do
          @diff_mail = Contact.make(:first_name => "ale")
          @diff_mail.contact_attributes << Email.make(:value => "asdfasdf@asdf.com")

          @regex = Contact.make(:first_name => "Alejandro")
          @regex.contact_attributes << Email.make(:value => "dwanardo@lepes.com")
          @regex.save

          @w_phone = Contact.make(:first_name => "Aleman")
          @w_phone.contact_attributes << Email.make(:value => "dwalico@mail.com")
          @w_phone.contact_attributes << Telephone.make(:value => "12341234")
        end

        context "{:email => 'dwa', :first_name => 'Ale'}" do
          before do
            post :search, :app_key => V0::ApplicationController::APP_KEY,
                :where => {:email => "dwa", :first_name => "Ale"}
          end
          it "should build Criteria" do
            assigns(:contacts).selector.should == {
                "first_name" => /Ale/i,
                contact_attributes: { '$elemMatch' => { "_type" => "Email", "value" => /dwa/i}}
            }
          end
          it "should return contacts that match ALL conditions." do
            assigns(:contacts).should include(@regex)
          end
          it "should not return contacts that match only some of the conditions" do
            assigns(:contacts).should_not include(@diff_mail)
          end
          it "should considers conditions as regex" do
            assigns(:contacts).should include(@regex)
          end
        end

        context "{:email => 'dwa', :first_name => 'Ale', :telephone => '1234'}" do
          before do
            post :search, :app_key => V0::ApplicationController::APP_KEY,
                :where => {:email => "dwa", :first_name => "Ale", :telephone => "1234"}
          end
          it { assigns(:contacts).count.should == 1}
          it "should return contacts that match ALL conditions." do
            assigns(:contacts).should include(@w_phone)
          end
          it "should not return contacts that match only some of the conditions" do
            assigns(:contacts).should_not include(@regex)
            assigns(:contacts).should_not include(@diff_mail)
          end
        end

        context "{ :value => 'salti'}" do
          before do
            @addressed = Contact.make
            @addressed.contact_attributes << Address.make(:value => "saltin 23")
            @addressed.save

            post :search, :app_key => V0::ApplicationController::APP_KEY,
                :where => { :contact_attributes => {:value => "salti"} }
          end
          it "should match street" do
            assigns(:contacts).to_a.should include(@addressed)
          end
          it "should match city"
        end
      end
    end
  end

  describe "#show" do
    before(:each) do
      @contact = Contact.first
      @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "1234321")
      @contact.contact_attributes << Email.make(:account => Account.make, :public => true)
      @contact.contact_attributes << Address.make(:account => Account.make, :public => false)

      @contact.local_unique_attributes <<  LocalStatus.make
      @contact.local_unique_attributes <<  LocalStatus.make
      @local_status = LocalStatus.make(account: @contact.owner)
      @contact.local_unique_attributes <<  @local_status

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

      it "should include all local_statuses" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:local_statuses].count.should == 3
      end
    end

    describe "when scoped to an account" do
      before(:each) do
        @contact.contact_attributes << Telephone.make(account: Account.make, public: false, value: "99999999")
        get :show, :id => @contact.id, :account_name => @contact.owner.name, :app_key => V0::ApplicationController::APP_KEY
      end
      it "should include contact_attributes visible to that account and masked phones" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:contact_attributes].count.should == 3
      end
      it "should include local_status of the account" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:local_status].should == @local_status.status.to_s
      end
      it "should include masked phones" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:contact_attributes].map{|ca|ca['value']}.should include("9999####")
      end
      it "should include all local_statuses" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:local_statuses].count.should == 3
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

  describe "image update" do
    context "if it recieves image" do
      before(:each) do
        @image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        @new_image = fixture_file_upload('spec/support/robot3.jpg', 'image/jpg')
        @new_contact = Contact.make(:avatar => @image)
        @file_url = @new_contact.avatar.url
        put  :update,
             :id => @new_contact.id,
             :contact => {:avatar => @new_image},
             :app_key => V0::ApplicationController::APP_KEY
      end
      it "should replace old image with new one" do
        @new_contact.reload
        @new_contact.avatar.url.should_not match /.ghibli_main_logo.gif/
      end
      it "should store it to amazon and link it to contact" do
        @new_contact.reload
        @new_contact.avatar.url.should match /.robot3.jpg/
      end
      after(:each) do
        Contact.last.remove_avatar!
      end
    end
    describe "attribute remove_avatar" do
      before(:each) do
        @image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        @new_contact = Contact.make(:avatar => @image)
        @file_url = @new_contact.avatar.url
        put  :update,
             :id => @new_contact.id,
             :contact => {:remove_avatar => true},
             :app_key => V0::ApplicationController::APP_KEY
      end
      
      it "should delete avatar" do
        Contact.last.avatar.should be_blank
      end
      
      after(:each) do
        Contact.last.remove_avatar!
      end
    end
  end

  describe "#update" do
    context "for a contact owned by account A" do
      before do
        @account_a = Account.make(name: 'account-a')
        @contact = Contact.make(owner: @account_a)
        @contact.contact_attributes << Email.make(value: 'unmail@valido.com', account: @account_a)
        @contact.save!
      end
      context "with a private attribute owned by account B" do
        before do
          account_b = Account.make(name: 'account-b')
          @contact.contact_attributes << Telephone.make(category: 'mobile', public: false, value: '12345678', account: account_b)
          @contact.save!
        end
        describe "update" do
          before do
            put :update, :id => @contact.id, :contact => {:coefficient => "pmenos"},
                :app_key => V0::ApplicationController::APP_KEY
          end
          it "should save contact correctly" do
            should respond_with :success
          end
        end
        describe "update after a get" do
          before do
            get :show, id: @contact.id, account_name: @account_a.name
            put :update, :id => @contact.id, :contact => {:coefficient => "pmenos"},
                :app_key => V0::ApplicationController::APP_KEY
          end
          it "should save contact correctly" do
            should respond_with :success
          end
        end
      end
    end
    describe "contact: {first_name: 'asdf'}" do
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

    it "should call deep_error_messages for errors" do
      Contact.any_instance.should_receive(:deep_error_messages)
      c = Contact.make
      put :update, id: c.id, contact: { first_name: nil },
          app_key: V0::ApplicationController::APP_KEY
    end

    it "should not check for duplicates" do
      a = Account.make
      c = Contact.make(first_name: 'dwayne', last_name: '')
      similar = Contact.make(first_name: 'dwayne', last_name: '', check_duplicates: false)

      similar.gender.should_not == 'male'

      put :update, id: similar.id, contact: {gender: 'male'},
          app_key: V0::ApplicationController::APP_KEY

      similar.reload.gender.should == 'male'
    end

    #Commenting out these tests as this functionality is not being used, but they reflect the issue correctly. LP
    #
    #describe "contact: {contact_attributes_attributes: ['....']}" do
    #  before do
    #    @contact = Contact.first
    #    @new_first_name = "Homer"
    #    put :update, :id => @contact.id,
    #        "contact"=>{"contact_attributes_attributes"=>["{\"type\"=>\"Telephone\", \"category\"=>\"home\", \"value\"=>\"54321\", \"public\"=>1}"]},
    #        :app_key => V0::ApplicationController::APP_KEY
    #  end
    #  it "should create new contact_attributes of the right type" do
    #    @contact.reload
    #    @contact.contact_attributes.last._type.should == "Telephone"
    #  end
    #  it "should add new contact_attributes" do
    #    @contact.reload
    #    @contact.telephones.last.value.should == "54321"
    #  end
    #end
  end


  describe "local_status in update" do
    before do
      @account = Account.make
      @contact = Contact.make(owner: @account)
      @contact.local_unique_attributes <<  LocalStatus.make
      @contact.local_unique_attributes <<  LocalStatus.make(account: @account)
      @contact.save
    end
    context "without :account_id" do
      before do
        put :update, :app_key => V0::ApplicationController::APP_KEY,
            :id => @contact.id,
            :contact => { :local_status => :student }
      end
      it "should ignore local_status if given" do
        @contact.reload
        @contact.local_statuses.where(account_id: @account.id).first.status.should == :prospect
      end
    end
    context "with :account_id" do
      context "of an account that already has local_status" do
        before do
          put :update, :app_key => V0::ApplicationController::APP_KEY,
              :id => @contact.id,
              :account_name => @account.name,
              :contact => { :local_status => :student }
        end
        it "should change local_status for given account" do
          @contact.reload
          @contact.local_statuses.where(account_id: @account.id).first.status.should == :student
        end
        it "should not create or delete local_statuses" do
          @contact.reload
          @contact.local_statuses.count.should == 2
        end
      end
      context "of an account without local_status" do
        before do
          account = Account.make
          @contact.lists << account.lists.first
          @contact.save
          put(:update, :app_key => V0::ApplicationController::APP_KEY,
              :id => @contact.id,
              :account_name => account.name,
              :contact => { :local_status => :student })
        end
        it "should create local status" do
          @contact.reload
          @contact.local_statuses.count.should == 3
        end
      end
    end
  end

  describe "#link" do
    let(:contact){Contact.make}
    let(:account){Account.make}
    before do
      contact.should_not be_linked_to account
      post :link, :id => contact.id,
          :account_name => account.name,
          :app_key => V0::ApplicationController::APP_KEY
    end
    it { should respond_with :success }
    it "should link contact to :account_name" do
      contact.should be_linked_to account
    end
  end

  describe "#create" do
    it "should create a contact" do
      expect{post :create,
                  :contact => Contact.plan,
                  :app_key => V0::ApplicationController::APP_KEY}.to change{Contact.count}.by(1)
    end

    it "posts to activity stream" do
      ActivityStream::Activity.any_instance.should_receive(:create)
      post :create,
           :contact => Contact.plan,
           :app_key => V0::ApplicationController::APP_KEY
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

    it "should respect model validations" do
      expect{post :create,
                  :contact => Contact.plan(:first_name => ""),
                  :app_key => V0::ApplicationController::APP_KEY }.not_to change{Contact.count}
    end

    it "should use Contact#deep_error_messages" do
      Contact.any_instance.should_receive(:deep_error_messages)
      post :create,
           :contact => Contact.plan(:first_name => ""),
           :app_key => V0::ApplicationController::APP_KEY
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
        @account.base_list.contacts.should include(assigns(:contact))
      end
    end

    it "should not set the owner if not scoped to an account" do
      post :create,
           :contact => Contact.plan(:owner => nil),
           :app_key => V0::ApplicationController::APP_KEY

      Contact.last.owner.should be_nil
    end
    context "if it recieves image via File Upload" do
      before(:each) do
        @image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        @account = Account.make
        post :create,
             :account_name => @account.name,
             :contact => Contact.plan(:owner => nil, :avatar => @image),
             :app_key => V0::ApplicationController::APP_KEY
      end
      it "should store an avatar image to the contact" do
        Contact.last.avatar.should_not be_blank
      end
      it "should have a URL" do
        Contact.last.avatar.url.should_not be_nil
      end
      it "should have a valid URL" do
        Contact.last.avatar.url.should match /.ghibli_main_logo\.gif/
      end
      after(:each) do
        Contact.last.remove_avatar!
      end
    end

    context "if it recieves image via URL" do
      pending "SPEC implemented but marked pending to avoid network connection on every spec run" do
      before(:each) do
        @image_url = "http://airbendergear.com/wp-content/uploads/2009/12/aang1.jpg"
        @account = Account.make
        post :create,
             :account_name => @account.name,
             :contact => Contact.plan(:owner => nil, :remote_avatar_url => @image_url),
             :app_key => V0::ApplicationController::APP_KEY
           end
       it "should store an avatar image to the contact" do
        Contact.last.avatar.should_not be_blank
        end
        it "should have a URL" do
          Contact.last.avatar.url.should_not be_nil
        end
        it "should have a valid URL" do
          Contact.last.avatar.url.should match /.aang1\.jpg/
        end
        after(:each) do
          Contact.last.remove_avatar!
        end
      end
    end
    
  end

  describe "#destroy" do
    before do
      @account = Account.make
      @contact = Contact.make(owner: @account)
    end
    describe "as the owner" do
      let(:params){{:id => @contact.id,
                    :account_name => @account.name,
                    :app_key => V0::ApplicationController::APP_KEY}}
      it "should unlink the contact" do
        prev = @account.contacts.count
        delete :destroy, params
        @account.reload
        @account.contacts.count.should == prev-1
      end
      it "should not destroy the contact" do
        owner = @contact.owner
        expect{delete :destroy, params}.not_to change{Contact.count}.by(-1)
      end
    end
    describe "as a viewer/editor" do
      let(:params){{:method => :delete,
                    :id => @contact.id,
                    :app_key => V0::ApplicationController::APP_KEY}}
      it "should not delete the contact" do
        expect{post :destroy, params}.not_to change{Contact.count}
      end
    end
  end

  describe "#destroy_multiple" do
    before do
      @account = Account.make
      @contacts = []
      3.times { @contacts << Contact.make(owner: @account) }
    end
    context "as the owner" do
      let(:params){{:method => :delete,
                    :ids => @contacts.map(&:_id),
                    :account_name => @account.name,
                    :app_key => V0::ApplicationController::APP_KEY}}
      it "should unlink owned contacts" do
        expect{post :destroy_multiple, params}.to change{@account.contacts.count}.by(-3)
      end
      it "should skip deletion of any not-owned contact" do
        @contacts << Contact.make(owner: Account.make)
        expect{post :destroy_multiple, params}.to change{@account.contacts.count}.by(-3)
      end
    end
    context "as non-owner" do
      it "should not delete the contacts" do
        expect{post :destroy_multiple, :method => :delete,
                    :ids => @contacts.map(&:_id),
                    :app_key => V0::ApplicationController::APP_KEY}.not_to change{Contact.count}
      end
    end
  end

end
