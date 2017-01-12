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

  describe "#similar" do
    def do_request(params)
      get :similar, params.merge(app_key: V0::ApplicationController::APP_KEY)
    end
    
    let!(:original){Contact.make first_name: 'Dwayne', last_name: 'Macgowan'}
    let!(:similar_contact){Contact.make first_name: 'Dwayne', last_name: 'Macgowan'}

    it "returns array of similar contacts" do
      do_request(id: original.id)
      res = ActiveSupport::JSON.decode(response.body)
      expect(res["total"]).to eq 1
      
      expect(res["collection"]).to eq([
        similar_contact.as_json(select: [
          :first_name,
          :last_name,
          :status
        ])
      ])
    end
  end

  describe "#index" do
    def do_request(params)
      get :index, params.merge(app_key: V0::ApplicationController::APP_KEY)
    end

    describe "paginates" do
      before do
        9.times { Contact.make }
        @isp = Contact.make(name: "in_second_page")
      end
      it "should return page 1" do
        do_request(:page => 1)
        ActiveSupport::JSON.decode(response.body)["total"].should == Contact.count
        assigns(:contacts).should_not include(@isp)
      end
      it "should return page 2" do
        do_request(:page => 2)
        ActiveSupport::JSON.decode(response.body)["total"].should == Contact.count
        assigns(:contacts).should include(@isp)
      end

      describe "if respect_ids_order is given" do
        let!(:c0){ Contact.make gender: 'male' }
        let!(:c1){ Contact.make gender: 'male' }
        let!(:c2){ Contact.make gender: 'male' }
        let!(:c3){ Contact.make gender: 'male' }
        let!(:c4){ Contact.make gender: 'female' }
        let!(:c5){ Contact.make gender: 'male' }
        describe "with page: 1" do
          it "returns first page elements respecting params[:ids] order" do
            do_request(respect_ids_order: true,
                       where: { gender: 'male' },
                       ids: [c2,c4,c3,c1].map(&:id),
                       page: 1,
                       per_page: 2)
            assigns(:contacts).to_a.should eq [c2, c3]
          end
        end
        describe "with page: 2" do
          it "returns second page elements respecting params[:ids] order" do
            do_request(respect_ids_order: true,
                       where: { gender: 'male' },
                       ids: [c2,c4,c3,c1].map(&:id),
                       page: 2,
                       per_page: 2)
            assigns(:contacts).to_a.should eq [c1]
          end
        end
        describe "when using :order_ids" do
          it "includes in the end contacts not included in :order_ids" do
            do_request(respect_ids_order: true,
                       where: { gender: 'male' },
                       order_ids: [c2,c4,c3,c1].map(&:id),
                       page: 1)
            assigns(:contacts).map(&:id).should eq [c2,c3,c1,c0,c5].map(&:id)
            #assigns(:contacts).to_a.should eq [c2,c3,c1,c0,c5]
          end
        end
      end
    end
    
    context "without params" do
      before do
        get :index, :app_key => V0::ApplicationController::APP_KEY
      end
      it { response.should be_success }
      it { assigns(:contacts).should_not be_nil }
      it "should show total amount of contacts" do
        result = ActiveSupport::JSON.decode(response.body)
        result["total"].should == 2
      end
    end

    context "specifying valid account and list_name" do
      let!(:account_a){ Account.make name: 'a' }
      let!(:account_b){ Account.make name: 'b' }
      let!(:list_a){ List.make account: account_a, name: 'a' }
      let!(:list_b){ List.make account: account_b }
      before do
        3.times do
          list_a.contacts << Contact.make
        end

        @contact_b = Contact.make
        list_b.contacts << @contact_b

        l = List.make(:account => account_a )
        @contact_l = Contact.make
        l.contacts << @contact_l

        get :index, {:account_name => "a", :list_name => "a", :app_key => V0::ApplicationController::APP_KEY}
      end
      it { should respond_with 200 }
      it { assigns(:contacts).should_not be_nil }
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
        @first_name.contact_attributes << Telephone.new(account_id: account._id, value: "12341234")
        @first_name.save

        @email = Contact.make(last_name: "mac")
        @email.contact_attributes << Email.new(account_id: account._id, value: "other@mail.com")
        @email.contact_attributes << Email.new(account_id: account._id, value: "dwaynemac@gmail.com")
        @email.save

        @last_name = Contact.make(first_name: "asdf", last_name: "dwayne")
      end

      context ":ids" do
        before do
          do_request(:ids => [@first_name.id,@email.id])
        end
        it "should only include contacts specified by ids" do
          assigns(:contacts).should include(@first_name)
          assigns(:contacts).should include(@email)
          assigns(:contacts).should_not include(@last_name)
        end
      end

      context ":full_text it will make a full text search" do
        before do
          do_request(:full_text => "dwayne")
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

          do_request(:full_text => "Son Gok")
        end
        it "should match all words" do
          assigns(:contacts).should include(@goku_contact)
          assigns(:contacts).should_not include(@gohan_contact)
        end
      end

      context "with blank :full_text" do
        before do
          do_request(:full_text => "")
        end
        it { response.should be_success }
        it { assigns(:contacts).should_not be_nil }
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
            do_request(:where => {:email => "dwa", :first_name => "Ale"})
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
            do_request(:where => {:email => "dwa", :first_name => "Ale", :telephone => "1234"})
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
            do_request(:where => { :address => "salti" })
          end
          it "should match street" do
            @addressed.in?(assigns(:contacts).to_a).should be_truthy
          end
          it "should match city"
        end
      end
    end
  end

  describe "#search_for_select" do
    describe "with app_key" do
      before do
        get :search_for_select, format: :js, app_key: V0::ApplicationController::APP_KEY
      end
      it { should respond_with 200 }
    end
    describe "with readonly_key" do
      before do
        get :search_for_select, format: :js, app_key: ENV['readonly_key']
      end
      it { should respond_with 200 }
    end
  end

  describe "#show_by_kshema_id" do
    describe "with kshema_id" do
      describe "if contact doesnot exist" do
        before do
          get :show_by_kshema_id, kshema_id: '1234', app_key: V0::ApplicationController::APP_KEY
        end
        it { should respond_with 404 }
      end
      describe "if contact exists" do
        before do
          @contact = Contact.make(kshema_id: '1234')
          get :show_by_kshema_id, kshema_id: '1234', app_key: V0::ApplicationController::APP_KEY
        end
        it { should respond_with(:success)}
        it "returns contact with given kshema_id" do
          assigns(:contact).should == @contact
        end
      end
    end
    describe "without kshema_id" do
      before do
        @contact = Contact.make(kshema_id: '1234')
        get :show_by_kshema_id, app_key: V0::ApplicationController::APP_KEY
      end
      it { should respond_with(400)}
    end
  end

  describe "#show" do
    before(:each) do
      @contact = Contact.first
      @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "12343210")
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

      it { response.should be_success }
      it { assigns(:contact).should_not be_nil }
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
        result[:contact_attributes].map{|ca|ca['value']}.should include("####9999")
      end
      it "should include all local_statuses" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:local_statuses].count.should == 3
      end
    end

    describe "when requesting a nil value in select params" do
      it "should reject the nil argument" do
        @contact.contact_attributes << Telephone.make(account: Account.make, public: false, value: "99999999")
        expect {get :show, 
            :id => @contact.id, 
            :account_name => @contact.owner.name, 
            :app_key => V0::ApplicationController::APP_KEY,
            :select => ["first_name", "last_name", nil]}.not_to raise_exception
      end
    end

    describe "when scoped to an account but specifing include_masked: false" do
      before(:each) do
        @contact.contact_attributes << Telephone.make(account: Account.make, public: false, value: "99999999")
        get :show, :id => @contact.id, :account_name => @contact.owner.name, :app_key => V0::ApplicationController::APP_KEY, :include_masked => false
      end
      it "should not include masked phones" do
        result = ActiveSupport::JSON.decode(response.body).symbolize_keys
        result[:contact_attributes].map{|ca|ca['value']}.should_not include("####9999")
      end
    end

    describe "include_masked option ->" do
      let(:contact){Contact.make}

      def set_status(contact,status)
        local_status = LocalStatus.make(account: contact.owner, value: status)
        contact.local_unique_attributes <<  local_status
        
        contact.save!
      end

      before do
        contact.contact_attributes << Telephone.make(account: Account.make, public: false, value: "99999999")
      end
      let(:result){ActiveSupport::JSON.decode(response.body).symbolize_keys}
      describe "when scoped to an account" do
        describe "but specifing include_masked: false" do
          before do
            get :show,
                id: contact.id,
                account_name: contact.owner.name,
                app_key: V0::ApplicationController::APP_KEY,
                include_masked: false
          end
          it "should not include masked phones" do
            result[:contact_attributes].map{|ca|ca['value']}.should_not include("####9999")
          end
        end
        describe "if contact is student in account" do
          let(:status){:student}
          before do
            set_status(contact,status)
            get :show,
                id: contact.id,
                account_name: contact.owner.name,
                app_key: V0::ApplicationController::APP_KEY
          end
          it "should not include masked phones" do
            result[:contact_attributes].map{|ca|ca['value']}.should_not include("####9999")
          end
        end
        describe "if contact is former_student in account" do
          let(:status){:former_student}
          before do
            set_status(contact,status)
            get :show,
                id: contact.id,
                account_name: contact.owner.name,
                app_key: V0::ApplicationController::APP_KEY
          end
          it "should not include masked phones" do
            result[:contact_attributes].map{|ca|ca['value']}.should_not include("####9999")
          end
        end
        describe "if contact has other status in account" do
          let(:status){nil}
          before do
            set_status(contact,status)
            get :show,
                id: contact.id,
                account_name: contact.owner.name,
                app_key: V0::ApplicationController::APP_KEY
          end
          it "should not include masked phones" do
            result[:contact_attributes].map{|ca|ca['value']}.should include("####9999")
          end
        end
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
            get :show, id: @contact.id, account_name: @account_a.name,
                :app_key => V0::ApplicationController::APP_KEY
            put :update,
                :id => @contact.id,
                :contact => {:coefficient => "pmenos"},
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

    describe "allow to ignore validation with flag ignore_validation:" do
      let(:account){Account.make}
      before do
        @invalid_contact = Contact.new status: :prospect
        @invalid_contact.save validate: false
        account.link(@invalid_contact)
      end
      
      describe "true, " do
        it "wont validate contact on update" do
          put :update, id: @invalid_contact.id, contact: { local_satus: :student },
              ignore_validation: true, account_name: account.name,
              app_key: V0::ApplicationController::APP_KEY
          should respond_with 200
        end
        describe "level" do
          before do
            put :update, id: @invalid_contact.id, contact: { level: :aspirante },
                ignore_validation: true, account_name: account.name,
                app_key: V0::ApplicationController::APP_KEY
          end
          it "is white listed" do
            @invalid_contact.reload.level.to_sym.should == :aspirante
          end
        end
        describe "local_status" do
          before do
            put :update, id: @invalid_contact.id, contact: { local_status: :student },
                ignore_validation: true, account_name: account.name,
                app_key: V0::ApplicationController::APP_KEY
          end
          it "is white listed" do
            @invalid_contact.reload.local_statuses.last.value.should == :student
          end
          it "updates global status too" do
            @invalid_contact.reload.status.should == :student
          end
        end
        describe "local_teacher" do
          before do
            @invalid_contact.status = :student
            @invalid_contact.save validate: false
            put :update, id: @invalid_contact.id, contact: { local_teacher: 'dwayne.mac'},
                ignore_validation: true, account_name: account.name,
                app_key: V0::ApplicationController::APP_KEY
          end
          it "is white listed" do
            @invalid_contact.reload.local_teachers.last.value.should == 'dwayne.mac'
          end
          it "updates global status too" do
            @invalid_contact.reload.global_teacher_username.should == 'dwayne.mac'
          end
        end
        describe "last_seen_at" do
          let(:now){Time.zone.parse('2015-2-1 12:32')}
          before do
            @invalid_contact.status = :student
            @invalid_contact.save validate: false
            put :update, id: @invalid_contact.id, contact: { last_seen_at: now},
                ignore_validation: true, account_name: account.name,
                app_key: V0::ApplicationController::APP_KEY
          end
          it "is white listed" do
            @invalid_contact.reload.last_seen_ats.last.value.to_date.should == now.to_date
          end
        end
        it "wont allow setting any other attribute"
      end
      describe "false, " do
        it "will validate contact" do
          put :update, id: @invalid_contact.id, contact: { local_satus: :student },
              app_key: V0::ApplicationController::APP_KEY
          should respond_with 400
        end
      end

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

    context "#tag_ids_for_request_account" do
      describe "erasing a tag but leaving the contact with tags" do
        before do
          @account = Account.make(name: "belgrano")
          @contact = Contact.make(owner: @account)
          @contact.request_account_name = @account.name
          @tag = Tag.make(account_id: @account.id)
          @another_tag = Tag.make(account_id: @account.id)
          @contact.tags << @tag
          @contact.tags << @another_tag
          @contact.save
          put :update, id: @contact.id, :contact => {tag_ids_for_request_account: [@tag.id]},
              :account_name => @account.name,
              :app_key => V0::ApplicationController::APP_KEY
        end
        it "should be consecuent with tag_ids_for_request_account" do
          @contact.save
          @contact.reload.tag_ids_for_request_account.should == @contact.tags.where(account_id: @account.id).map(&:id)
          @contact.reload.tag_ids_for_request_account.should == [@tag.id]
        end
        it "should update the contact tags and leave one tag" do
          @contact.save
          @contact.reload.tags.count.should == 1
          @contact.tags.last.should == @tag
        end
      end

      describe "erasing a tag but leaving the contact with tags from another account" do
        before do
          @account = Account.make(name: "belgrano")
          @another_account = Account.make(name: "cervino")
          @contact = Contact.make(owner: @account)
          @contact.request_account_name = @account.name
          @tag = Tag.make(account_id: @account.id)
          @another_tag = Tag.make(account_id: @another_account.id)
          @contact.tags << @tag
          @contact.tags << @another_tag
          @contact.save
          put :update, id: @contact.id, :contact => {tag_ids_for_request_account: ""},
              :account_name => @account.name,
              :app_key => V0::ApplicationController::APP_KEY
        end
        it "should be consecuent with tag_ids_for_request_account" do
          @contact.save
          @contact.reload.tag_ids_for_request_account.should == @contact.tags.where(account_id: @account.id).map(&:id)
          @contact.reload.tag_ids_for_request_account.should == []
        end
        it "should update the contact tags and leave one tag" do
          @contact.save
          @contact.reload.tags.count.should == 1
          @contact.tags.last.should == @another_tag
        end
      end

      describe "erasing a tag and leaving the contact without tags" do
        before do
          @account = Account.make(name: "belgrano")
          @contact = Contact.make(owner: @account)
          @contact.request_account_name = @account.name
          @tag = Tag.make(account_id: @account.id)
          @contact.tags << @tag
          @contact.save
          put :update, id: @contact.id, :contact => {tag_ids_for_request_account: ""},
              :account_name => @account.name,
              :app_key => V0::ApplicationController::APP_KEY
        end
        it "should update the contact tags" do
          @contact.save
          @contact.reload.tags.count.should == 0
        end
      end
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
        it "should create local status" do
          account = Account.make name: 'theaccname'
          account.link(@contact)
          expect(@contact.local_status_for_theaccname).to be_nil
          put(:update, :app_key => V0::ApplicationController::APP_KEY,
              :id => @contact.id,
              :account_name => account.name,
              :contact => { :local_status => :student })
          @contact.reload
          expect(@contact.local_status_for_theaccname).to eq :student
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
      contact.reload.should be_linked_to account
    end
  end

  describe "#create with find_or_create flag" do
    let(:account){Account.make}
    let(:contact_attributes){
      {
        first_name: 'Ramona',
        last_name: 'Flowers',
        contact_attributes_attributes: [ 
          {_type: 'Email', value: 'ramona@flower.com'},
          {_type: 'Telephone', value: '12341234'}
        ]
      }
    }

    describe "if id is given" do
      let!(:dup){Contact.make}
      it "should not create a new contact" do
        expect{post :create,
                    contact: contact_attributes,
                    account_name: account.name,
                    find_or_create: true,
                    id: dup.id,
                    app_key: V0::ApplicationController::APP_KEY
        }.not_to change{Contact.count}
      end
      it "should copy received attributes to contact of given id" do
        post :create,
            contact: contact_attributes,
            account_name: account.name,
            find_or_create: true,
            id: dup.id,
            app_key: V0::ApplicationController::APP_KEY
        dup.reload
        expect(dup.telephones.count).to eq 1
      end
    end

    describe "if duplicates exist" do
      let(:dup){Contact.make}
      before do
        dup.contact_attributes << Email.make(value: 'ramona@flower.com',
                                             account: account)
      end
      it "should not create a contact" do
        expect{post :create,
                    contact: contact_attributes,
                    account_name: account.name,
                    find_or_create: true,
                    app_key: V0::ApplicationController::APP_KEY
        }.not_to change{Contact.count}
      end
      it "should link contact to account_name" do
        post :create,
             contact: contact_attributes,
             account_name: account.name,
             find_or_create: true,
             app_key: V0::ApplicationController::APP_KEY
        expect(Contact.last.accounts).to include account
      end
      it "should add attributes to the contact" do
        post :create,
            contact: contact_attributes,
            account_name: account.name,
            find_or_create: true,
            app_key: V0::ApplicationController::APP_KEY
        expect(Contact.last.telephones.count).to eq 1
      end
      it "should not duplicate existing attributes" do
        post :create,
            contact: contact_attributes,
            account_name: account.name,
            find_or_create: true,
            app_key: V0::ApplicationController::APP_KEY
        expect(Contact.last.emails.where(account_id: account.id).count).to eq 1
      end
      it "should add first_name as custom_attribute" do
        post :create,
            contact: contact_attributes,
            account_name: account.name,
            find_or_create: true,
            app_key: V0::ApplicationController::APP_KEY
        expect(Contact.last.custom_attributes.where(name: 'other first name').first.value).to eq contact_attributes[:first_name]
      end
      it "should add last_name as custom_attribute" do
        post :create,
            contact: contact_attributes,
            account_name: account.name,
            find_or_create: true,
            app_key: V0::ApplicationController::APP_KEY
        expect(Contact.last.custom_attributes.where(name: 'other last name').first.value).to eq contact_attributes[:last_name]
      end
    end
    describe "if there is no duplicate" do
      it "should create a contact" do
        expect{post :create,
                    contact: contact_attributes,
                    find_or_create: true,
                    app_key: V0::ApplicationController::APP_KEY}.to change{Contact.count}.by(1)
      end
    end
  end

  describe "#create" do
    before do
      @account = Account.make(name: "belgrano")
    end

    it "should create a contact" do
      expect{post :create,
                  :contact => Contact.plan,
                  :app_key => V0::ApplicationController::APP_KEY}.to change{Contact.count}.by(1)
    end

    it "posts to activity stream" do
      ActivityStream::Activity.any_instance.should_receive(:create)
      post  :create,
            :contact => Contact.plan,
            :app_key => V0::ApplicationController::APP_KEY,
            :account_name => "belgrano",
            :username => "Luis"
    end

    describe "should create a contact with attributes" do
      before do
        post  :create,
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
      it "should link contact to the account" do
        expect(@account.contacts).to include assigns(:contact)
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
        expect{delete :destroy, params}.not_to change{Contact.count}
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
    context "without :ids" do
      let(:params){{:method => :delete,
                    :account_name => @account.name,
                    :app_key => V0::ApplicationController::APP_KEY}}
      it "should fail safely" do
        expect{post :destroy_multiple, params}.not_to raise_exception
      end
      it "should return status 400" do
        post :destroy_multiple, params
        expect(response.code).to eq '400'
      end
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
