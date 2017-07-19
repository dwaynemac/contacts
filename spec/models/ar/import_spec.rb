# encoding: UTF-8
require 'csv'
require 'ar_spec_helper'

describe NewImport do
  before do
    @headers = %w(id dni nombres apellidos dire tel cel mail grado_id instructor_id coeficiente_id genero foto
                fecha_nacimiento inicio_practicas profesion	notes follow indice_fidelizacion codigo_postal school_id
                current_plan_id	created_at updated_at estimated_age	company	job	city locality business_phone
                country_id state identity publish_on_gdp last_enrollment in_formation id_scan padma_id foto_migrated
                id_scan_migrated padma_follow_id tags)
    @former_student = ["50001",	"30 366 832", "Dwayne",	"Macgowan", "Arribeños 2153 14B", "4783.6951", "15.4099.5071",
                 "dwaynemac@gmail.com",	"asistente", "daniel.ferztand", "exalumno", "male",
                 "spec/support/ghibli_main_logo.gif",
                 "1983-05-21", "2005-05-13", "Instr. Método DeRose", "<p>alguna observacion</p>", "true", "5",
                 "1428", "1", "", "", "2011-02-19 18:04:12 -0300", "", "", "", "", "", "", "", "", "",
                 "false", "", "", "", "", "", "", "",""]
    @student =  ["50010", "", "Alex", "Falke", "", "4782 1495",	"15 5466 7896",	"afalkear@gmail.com", "asistente",
                 "lucia.gagliardini", "alumno", "female",
                 "spec/support/ghibli_main_logo.gif", "1983-03-11", "2004-12-01",
                 "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",	"1667392", "",
                 "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "true", "", "", "", "", "",""]
    @student2 =  ["50010", "", "Alex", "Falke", "", "4782 1395", "14 5466 7896", "afkear@gmail.com", "asistente",
                 "lucia.gagliardini", "alumno", "female",
                 "spec/support/ghibli_main_logo.gif", "1983-03-11", "2004-12-01",
                 "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",  "1667392", "",
                 "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", "",""]
    @p_visit = ["50178", "", "Daniel", "Werber", "", "", "15 4437-6580", "werber@fibertel.com.ar", "aspirante", "",	"perfil", "female",
                "","","", "BioquÃ­mico", "", "false", "", "", "1", "", "", "", "", "", "", "", "", "", "", "", "", "false", 
                "", "", "", "", "", "", "","un-tag, otro-tag"]
    CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
      csv << @headers
      csv << @former_student
      csv << @student
      csv << @student2
      csv << @p_visit
    end
    # @csv_file = File.open("#{Rails.root}/spec/support/test.csv")
    extend ActionDispatch::TestProcess
    @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
    # @csv_file = Rack::Test::UploadedFile.new(Rails.root.join('spec/support/test.csv'), 'text/csv')
  end

  describe "create_contact" do
    context "with a correct CSV file" do
      before do
        @account = NewAccount.make
        @new_import = NewImport.make(account: @account, headers: @headers)
        @new_import.attachment = NewAttachment.new(name: "CSV", file: @csv_file, account: @account)
        @new_import.save
      end
      context "with all new contacts" do
        before do
          expect{@new_import.process_CSV_without_delay}.to change{NewContact.count}.by(3)
        end
        it "should have consistent data" do
          NewContact.last.first_name.should == "Daniel"
          NewContact.last.last_name.should == "Werber"
        end
        it "should create tags" do
          NewContact.last.tags.map(&:name).should == %W(un-tag otro-tag)
        end
        it "should have kshema_id" do
          NewContact.last.kshema_id.should == "50178"
        end
        it "should save birthday" do
          NewContact.first.birthday.date.should == Date.civil(1983,5,21)
        end
        it "should save inicio_practicas as a date" do
          NewContact.first.date_attributes.to_a.select{|da| da.category == 'Inicio practicas'}.first.date.should == Date.civil(2005,5,13)
        end
        it "should distinguish between levels" do
          NewContact.where(level: 5).count.should == 2
        end
        it "should distinguish between statuses" do
          NewContact.where(status: :student).count.should == 1
        end
        it "should maintain local status" do
          alex = NewContact.where(first_name: "Alex").first
          alex.local_status_for_testaccount.should == :student
        end
        it "should have the correct contact observation" do
          dwayne = NewContact.where(first_name: "Dwayne").first
          dwayne.local_unique_attributes.where(_type: "Observation").count.should == 1
          dwayne.local_unique_attributes.where(_type: "Observation").first.value.should == "<p>alguna observacion</p>"
        end
        it "should set gender correctly" do
          dwayne = NewContact.where(first_name: "Dwayne").first
          dwayne.gender.should == 'male'
        end
        it "should set in_professional_training correctly" do
          alex = NewContact.where(first_name: "Alex").first
          alex.in_professional_training.should be_truthy
        end
      end
      context "with a contact that is already in the database" do
        before do
          @new_contact = NewContact.new(first_name: "Dwayne", last_name: "Macgowan", owner: @account, check_duplicates: false)
          NewTelephone.new(value: 1540995071, category: "mobile", contact_id: @new_contact.id)
          NewEmail.new(value: "dwaynemac@gmail.com", contact_id: @new_contact.id)
        end
        it "should create all the contacts" do
          expect{@new_import.process_CSV_without_delay}.to change{NewContact.count}.by(3)
        end
        it "should duplicate the contact that already existed" do
          @new_import.process_CSV_without_delay
          NewContact.includes(:contact_attributes).where("contact_attributes.type = 'Email' AND contact_attributes.string_value = 'dwaynemac@gmail.com'").count.should == 2
          NewContact.where(first_name: "Dwayne").count.should == 2
        end
      end
      context "with images and attachments uri" do
        it "should save the avatar locally" do
          @new_import.process_CSV_without_delay
          alex = NewContact.where(first_name: "Alex").first
          alex.avatar.should_not be_nil
          alex.avatar.url.should match /ghibli_main_logo\.gif/
        end
      end
    end
    context "with an incorrect CSV file" do
      context "if contact has incorrect data" do
        before do
          @incorrect_student =  ["50013", "", "Alex", "Falke", "", "telefono errado", "15 5466 7896", "mail.mal.puesto", "6",
                   "lucia.gagliardini", "perfil", "h",
                   "spec/support/ghibli_main_logo.gif", "--/23/23", "2004-12-01",
                   "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",  "1667392", "",
                   "2013-01-11 14:03:29 -0300", "bad_age", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", "",""]
          CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
            csv << @headers
            csv << @incorrect_student
            csv << @former_student
            csv << @student
            csv << @incorrect_student
            csv << @p_visit
          end
          @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
          @account = NewAccount.make
          @new_import = NewImport.make(account: @account, headers: @headers)
          @new_import.attachment = NewAttachment.new(name: "CSV", file: @csv_file, account: @account)
          @new_import.save
        end
        it "should try to add every contact" do
          expect{@new_import.process_CSV_without_delay}.to change{NewContact.count}.by(4)
        end
        it "should resolve incorrect data given" do
          @new_import.process_CSV_without_delay
          @new_import.status.should == :finished
          cont = NewContact.where(kshema_id: "50013").first
          cont.should_not be_nil
          cont.emails.count.should == 0
          cont.telephones.count.should == 1
          cont.level.should be_nil
          cont.birthday.should be_nil
          cont.estimated_age.should be_nil
          cont.status.should == :prospect
          cont.custom_attributes.where(name: "rescued_phone_from_import", value: "telefono errado").count.should == 1
        end
      end
      context "if contact has duplicate email" do
        before do
          duplicate_contact = ["50013", "", "Alex", "Falke", "", "4782 1495",	"15 5466 7896",	"afalkear@gmail.com", "asistente",
           "lucia.gagliardini", "perfil", "male",
           "spec/support/ghibli_main_logo.gif", "1983-03-11", "2004-12-01",
           "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",	"1667392", "",
           "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", "",""]
          CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
            csv << @headers
            csv << duplicate_contact
            csv << @former_student
            csv << @student
            csv << @p_visit
          end
          @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
          @account = NewAccount.make
          @new_import = NewImport.make(account: @account, headers: @headers)
          @new_import.attachment = NewAttachment.new(name: "CSV", file: @csv_file, account: @account)
          @new_import.save
        end
        it "should add every contact" do
          expect{@new_import.process_CSV_without_delay}.to change{NewContact.count}.by(4)
        end
        it "should add email as a custom attribute" do
          @new_import.process_CSV_without_delay
          con = NewContact.where(kshema_id: "50013").first
          con.should_not be_nil
          con.emails.count.should > 0
          con.emails.last.value.should == "afalkear@gmail.com"
        end
      end
    end
  end

  describe "#failed_rows_to_csv" do
    before do
      # @incorrect_student =  ["50010", "", "Bernardo", "Gomez", "", "telefono errado", "15 5466 7896", "mail.mal.puesto", "6",
      #                        "lucia.gagliardini", "5", "h",
      #                        "/home/alex/workspace/Padma/public/persona/foto/50010/alex_web.jpg", "1983-03-11", "2004-12-01",
      #                        "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",  "1667392", "",
      #                        "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
      # CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
      #   csv << @headers
      #   csv << @incorrect_student
      #   csv << @former_student
      #   csv << @student
      #   csv << @incorrect_student
      #   csv << @p_visit
      # end
      extend ActionDispatch::TestProcess
      @csv_file = fixture_file_upload("#{Rails.root}/spec/support/belgrano_personas_incorrect.csv", "text/csv" )
      @account = NewAccount.make
      @new_import = NewImport.make(account: @account, headers: @headers)
      @new_import.attachment = NewAttachment.new(name: "CSV", file: @csv_file, account: @account)
      @new_import.save
    end
    it "should create all contacts except the one with errors" do
      expect{@new_import.process_CSV_without_delay}.to change{NewContact.count}.by(29)
    end
    it "should return a CSV with all the failed errors" do
      @new_import.process_CSV_without_delay
      csv = @new_import.failed_rows_to_csv
      csv.should_not be_nil
      # the failed person is Anoopa and her kshema_id is 50015
      csv.should include("un.mal.mail")
      # the failed row is 26
      csv.should include("16")
    end

  end

  describe "when import is destroyed" do
    let(:account){NewAccount.make}
    let(:attachment){NewAttachment.new(name: "CSV", file: @csv_file, account: account)}
    let(:import){NewImport.make(account: account, headers: @headers, attachment: attachment)}
    before do
      import.process_CSV_without_delay
      NewContact.count.should == 3
    end
    it "destroys all created contacts" do
      expect{import.destroy}.to change{NewContact.count}.by(-3)
    end
  end

  # Clean up
  after do
    File.delete("#{Rails.root}/spec/support/test.csv")
  end
end
