# encoding: UTF-8
require 'csv'
require 'spec_helper'

describe V0::ImportsController do
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
    #@csv_file = File.open("#{Rails.root}/spec/support/test.csv")
    extend ActionDispatch::TestProcess
    @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
    @account = Account.make(name: "testAccount")
  end

  describe "#create" do
    context "with a correct file" do
      before do
        post  :create,
              :app_key => V0::ApplicationController::APP_KEY,
              :import => { :file => @csv_file, :headers => @headers },
              :account_name => @account.name
      end
      it {should respond_with(201)}
      it "should return ID of import" do
        result = ActiveSupport::JSON.decode(response.body)
        result['id'].should_not be_blank
      end
    end
  end

  describe "#show" do
    context 'while working on an CSV file' do
      context 'without errors' do
        before do
          import = Import.create(account: @account, headers: @headers)
          import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
          import.process_CSV_without_delay
          import.update_attribute(:status, :working)
          get :show,
              :app_key => V0::ApplicationController::APP_KEY,
              :id => import.id,
              :account_name => @account.name
          @result = ActiveSupport::JSON.decode(response.body)
        end
        it {should respond_with(200)}
        it "should return status: :working" do
          @result['import']['status'].should == "working"
        end
        it "should return no failed rows" do
          @result['import']['failed_rows'].should == 0
        end
        it "should return imported rows" do
          @result['import']['imported_rows'].should == 3
        end
      end
      context 'with errors' do
        before do
          @incorrect_student =  ["50010", "", "Alex", "Falke", "", "telefono errado", "15 5466 7896", "mail.mal.puesto", "6",
                                 "lucia.gagliardini", "5", "h",
                                 "/home/alex/workspace/Padma/public/persona/foto/50010/alex_web.jpg", "1983-03-11", "2004-12-01",
                                 "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",  "1667392", "",
                                 "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
          CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
            csv << @headers
            csv << @former_student
            csv << @incorrect_student
            csv << @student
            csv << @incorrect_student
            csv << @p_visit
          end
          #@csv_file = File.open("#{Rails.root}/spec/support/test.csv")
          extend ActionDispatch::TestProcess
          @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
          import = Import.create(account: @account, headers: @headers)
          import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
          import.process_CSV_without_delay
          import.update_attribute(:status, :working)
          get :show,
              :app_key => V0::ApplicationController::APP_KEY,
              :id => import.id,
              :account_name => @account.name
          @result = ActiveSupport::JSON.decode(response.body)
        end
        it "should return status: :working" do
          @result['import']['status'].should == "working"
        end
        it "should return failed rows" do
          @result['import']['failed_rows'].should == 2
        end
        it "should return imported rows" do
          @result['import']['imported_rows'].should == 3
        end
      end
    end

    context 'when CSV file has finished' do
      before do
        import = Import.create(account: @account, headers: @headers)
        import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
        import.process_CSV_without_delay
        get :show,
            :app_key => V0::ApplicationController::APP_KEY,
            :id => import.id,
            :account_name => @account.name
        @result = ActiveSupport::JSON.decode(response.body)
      end
      it "should have status: :finished" do
        @result['import']['status'].should == "finished"
      end
    end
  end

  describe "#failed_rows" do
    before do
      @incorrect_student =  ["50010", "", "Alex", "Falke", "", "telefono errado", "15 5466 7896", "mail.mal.puesto", "6",
                             "lucia.gagliardini", "5", "h",
                             "/home/alex/workspace/Padma/public/persona/foto/50010/alex_web.jpg", "1983-03-11", "2004-12-01",
                             "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",  "1667392", "",
                             "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
      CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
        csv << @headers
        csv << @former_student
        csv << @incorrect_student
        csv << @student
        csv << @incorrect_student
        csv << @p_visit
      end
      #@csv_file = File.open("#{Rails.root}/spec/support/test.csv")
      extend ActionDispatch::TestProcess
      @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
      @import = Import.create(account: @account, headers: @headers)
      @import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
      @import.process_CSV_without_delay

    end
    context 'when CSV file has finished' do
      it "should send data" do
        @controller.should_receive(:send_data).and_return{ @controller.render :nothing => true }
        get :failed_rows,
            :app_key => V0::ApplicationController::APP_KEY,
            :id => @import.id,
            :account_name => @account.name,
            :format => :csv
      end
    end
  end

  describe "#destroy" do
    let(:account){Account.last || Account.make(name: "testAccount")}
    let(:attachment){Attachment.new(name: "CSV", file: @csv_file, account: account)}
    let(:import){Import.make(account: account, headers: @headers, attachment: attachment)}
    before do
      import.process_CSV_without_delay
    end
    def do_request
      delete :destroy, id: import.id, app_key: V0::ApplicationController::APP_KEY
    end
    describe "for import that has not started working" do
      before do
        import.update_attribute :status, :ready
        @count = import.imported_ids.count
        do_request
      end
      it { should respond_with 200 }
      it "destroys specified import" do
        Import.exists?(conditions: { id: import.id }).should be_false
      end
    end
    describe "for import that is still working" do
      before do
        import.update_attribute :status, :working
        do_request
      end
      # status codes definitions: http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
      it { should respond_with 409 }
      it "wont destroy specified import" do
        Import.exists?(conditions: { id: import.id }).should be_true
      end
    end
    describe "for import that finished proccessing" do
      before do
        import.update_attribute :status, :finished
      end
      it "responds 200" do
        do_request
        response.code.should == "200"
      end
      it "destroys specified import" do
        do_request
        Import.exists?(conditions: { id: import.id }).should be_false
      end
      it "destroys imported contacts" do
        c = import.imported_ids.count
        expect{do_request}.to change{Contact.count}.by (0-c)
      end
    end
  end
  # Clean up
  after do
    File.delete("#{Rails.root}/spec/support/test.csv")
  end
end
