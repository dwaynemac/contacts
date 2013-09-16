# encoding: UTF-8
require 'spec_helper'

describe V0::AttachmentsController do
  # TODO: add :only option to matcher
  # it_should_behave_like "Secure API Controller", :only => :update

  before do
    @contact = Contact.make
    attach = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
    @contact.attachments << Attachment.new(
      :account => @contact.owner, 
      :name => "name",
      :file => attach,
      :descripton => "description")
    @contact.save
    @contact.reload
  end


  describe "#update" do
    context "with app_key" do
      before do
        new_attach = fixture_file_upload('spec/support/robot3.jpg', 'image/jpg')
        put :update, :account_name => @contact.owner.name, :contact_id => @contact.id,
            :id => @contact.attachments.first.id, :attachment => {:file => new_attach},
            :app_key => V0::ApplicationController::APP_KEY
      end
      it { should respond_with :success }
      it "should change the name" do
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
      context "sending :name" do
        before do
          attach = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
          post :create, :account_name => @contact.owner.name, :contact_id => @contact.id,
               :attachment => { :name => "New Attachment", :file => attach},
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new file" do
          @contact.reload.attachments.count.should == 2
          @contact.reload.attachments.last.file.url.should match /ghibli_main_logo\.gif/
        end
        it "should assign attachment to account" do
          @contact.reload.attachments.last.account.should == @contact.owner
        end
      end
      context "sending a CSV file" do
        before do
          @headers = %w(id dni nombres apellidos dire tel cel mail grado_id instructor_id coeficiente_id genero foto
                fecha_nacimiento inicio_practicas profesion	notes follow indice_fidelizacion codigo_postal school_id
                current_plan_id	created_at updated_at estimated_age	company	job	city locality business_phone
                country_id state identity publish_on_gdp last_enrollment in_formation id_scan padma_id foto_migrated
                id_scan_migrated padma_follow_id)
          @former_student = ["50001",	"30 366 832", "Dwayne",	"Macgowan", "Arribeños 2153 14B", "4783.6951", "15.4099.5071",
                             "dwaynemac@gmail.com",	"asistente", "daniel.ferztand", "perfil", "male",
                             "/home/alex/workspace/Padma/public/persona/foto/50001/654da12b6a7905f62633eae7e76688c5.jpg",
                             "1983-05-21", "2005-05-13", "Instr. Método DeRose", "<p>algna observacion</p>", "true", "5",
                             "1428", "1", "", "", "2011-02-19 18:04:12 -0300", "", "", "", "", "", "", "", "", "",
                             "false", "", "", "", "", "", "", ""]
          @student =  ["50010", "", "Alex", "Falke", "", "4782 1495",	"15 5466 7896",	"afalkear@gmail.com", "asistente",
                       "lucia.gagliardini", "perfil", "male",
                       "https://fbcdn-sphotos-c-a.akamaihd.net/hphotos-ak-frc1/249140_10150188276702336_1924524_n.jpg", "1983-03-11", "2004-12-01",
                       "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",	"1667392", "",
                       "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
          @p_visit = ["50178", "", "Daniel", "Werber", "", "", "15 4437-6580", "werber@fibertel.com.ar", "aspirante", "",	"perfil", "male",
                      "","","", "BioquÃ­mico", "", "false", "", "", "1", "", "", "", "", "", "", "", "", "", "", "", "", "false",
                      "", "", "", "", "", "", ""]
          CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
            csv << @headers
            csv << @former_student
            csv << @student
            csv << @p_visit
          end
          extend ActionDispatch::TestProcess
          attach = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
          post :create, :account_name => @contact.owner.name, :contact_id => @contact.id,
               :attachment => { :name => "New Attachment", :file => attach},
               :app_key => V0::ApplicationController::APP_KEY
        end
        it { should respond_with :created }
        it "should create a new file" do
          @contact.reload.attachments.count.should == 2
        end
      end
    end
    context "called by un-linked account" do
      let(:other_account){Account.make}
      before do
        attach = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        post :create, :account_name => other_account.name, :contact_id => @contact.id,
             :attachment => {
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
             :attachment => {
                :name => "New Attach",
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
      it "should remove name from _keywords" do
        post :destroy, :method => :delete,
             :id => @attachment.id,
             :contact_id => @contact.id,
             :account_name => @contact.owner.name,
             :app_key => V0::ApplicationController::APP_KEY
        @contact.reload._keywords.should_not include(@attachment.name)
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