# encoding: UTF-8
require 'csv'
require File.dirname(__FILE__) + '/../spec_helper'

describe Import do
  before do
    @headers = %w(id dni nombres apellidos dire tel cel mail grado_id instructor_id coeficiente_id genero foto
                fecha_nacimiento inicio_practicas profesion	notes follow indice_fidelizacion codigo_postal school_id
                current_plan_id	created_at updated_at estimated_age	company	job	city locality business_phone
                country_id state identity publish_on_gdp last_enrollment in_formation id_scan padma_id foto_migrated
                id_scan_migrated padma_follow_id)
    @former_student = ["50001",	"30 366 832", "Dwayne",	"Macgowan", "Arribeños 2153 14B", "4783.6951", "15.4099.5071",
                 "dwaynemac@gmail.com",	"asistente", "daniel.ferztand", "perfil", "m",
                 "/home/alex/workspace/Padma/public/persona/foto/50001/654da12b6a7905f62633eae7e76688c5.jpg",
                 "1983-05-21", "2005-05-13", "Instr. Método DeRose", "<p>alguna observacion</p>", "true", "5",
                 "1428", "1", "", "", "2011-02-19 18:04:12 -0300", "", "", "", "", "", "", "", "", "",
                 "false", "", "", "", "", "", "", ""]
    @student =  ["50010", "", "Alex", "Falke", "", "4782 1495",	"15 5466 7896",	"afalkear@gmail.com", "asistente",
                 "lucia.gagliardini", "perfil", "m",
                 "https://fbcdn-sphotos-c-a.akamaihd.net/hphotos-ak-frc1/249140_10150188276702336_1924524_n.jpg", "1983-03-11", "2004-12-01",
                 "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",	"1667392", "",
                 "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
    @p_visit = ["50178", "", "Daniel", "Werber", "", "", "15 4437-6580", "werber@fibertel.com.ar", "aspirante", "",	"perfil", "m",
                "","","", "BioquÃ­mico", "", "false", "", "", "1", "", "", "", "", "", "", "", "", "", "", "", "", "false", 
                "", "", "", "", "", "", ""]
    CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
      csv << @headers
      csv << @former_student
      csv << @student
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
        @account = Account.make(name: "testAccount")
        @new_import = Import.make(account: @account, headers: @headers)
        @new_import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
        @new_import.save
      end
      context "with all new contacts" do
        it "should create given contacts" do
          expect{@new_import.process_CSV_without_delay}.to change{Contact.count}.by(3)
        end
        it "should have consistent data" do
          @new_import.process_CSV_without_delay
          Contact.last.first_name.should == "Daniel"
          Contact.last.last_name.should == "Werber"
        end
        it "should have kshema_id" do
          @new_import.process_CSV_without_delay
          Contact.last.kshema_id.should == "50178"
        end
        it "should distinguish between levels" do
          @new_import.process_CSV_without_delay
          Contact.where(level: 5).count.should == 2
        end
        it "should have the correct contact observation" do
          @new_import.process_CSV_without_delay
          dwayne = Contact.where(first_name: "Dwayne").first
          dwayne.local_unique_attributes.where(_type: "Observation").count.should == 1
          dwayne.local_unique_attributes.where(_type: "Observation").first.value.should == "<p>alguna observacion</p>"
        end
      end
      context "with a contact that is already in the database" do
        before do
          @new_contact = Contact.new(first_name: "Dwayne", last_name: "Macgowan", owner: @account, check_duplicates: false)
          @new_contact.contact_attributes << Telephone.new(value: 1540995071, category: "mobile")
          @new_contact.contact_attributes << Email.new(value: "dwaynemac@gmail.com")
          @new_contact.save!
        end
        it "should create all the contacts" do
          expect{@new_import.process_CSV_without_delay}.to change{Contact.count}.by(3)
        end
        it "should duplicate the contact that already existed" do
          @new_import.process_CSV_without_delay
          Contact.any_of(contact_attributes: { '$elemMatch' => {'_type' => 'Email', 'value' => 'dwaynemac@gmail.com'} }).count.should == 2
          Contact.where(first_name: "Dwayne").count.should == 2
        end
      end
      context "with images and attachments uri" do
        it "should save the avatar locally" do
          @new_import.process_CSV_without_delay
          alex = Contact.where(first_name: "Alex").first
          alex.avatar.should_not be_nil
          alex.avatar.url.should match /249140_10150188276702336_1924524_n\.jpg/
        end
      end
    end
    context "with an incorrect CSV file" do
      context "if contact has incorrect data" do
        before do
          @incorrect_student =  ["50013", "", "Alex", "Falke", "", "telefono errado", "15 5466 7896", "mail.mal.puesto", "6",
                   "lucia.gagliardini", "perfil", "h",
                   "/home/alex/workspace/Padma/public/persona/foto/50010/alex_web.jpg", "1983/03 fecha11", "2004-12-01",
                   "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",  "1667392", "",
                   "2013-01-11 14:03:29 -0300", "bad_age", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
          CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
            csv << @headers
            csv << @incorrect_student
            csv << @former_student
            csv << @student
            csv << @incorrect_student
            csv << @p_visit
          end
          @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
          @account = Account.make(name: "testAccount")
          @new_import = Import.make(account: @account, headers: @headers)
          @new_import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
          @new_import.save
        end
        it "should try to add every contact" do
          expect{@new_import.process_CSV_without_delay}.to change{Contact.count}.by(4)
        end
        it "should resolve incorrect data given" do
          @new_import.process_CSV_without_delay
          cont = Contact.where(kshema_id: "50013").first
          cont.should_not be_nil
          cont.emails.count.should == 0
          cont.level.should be_nil
          cont.birthday.should be_nil
          cont.estimated_age.should be_nil
          cont.status.should == :prospect
        end
      end
      context "if contact has duplicate email" do
        before do
          duplicate_contact = ["50013", "", "Alex", "Falke", "", "4782 1495",	"15 5466 7896",	"afalkear@gmail.com", "asistente",
           "lucia.gagliardini", "perfil", "male",
           "https://fbcdn-sphotos-c-a.akamaihd.net/hphotos-ak-frc1/249140_10150188276702336_1924524_n.jpg", "1983-03-11", "2004-12-01",
           "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",	"1667392", "",
           "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
          CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
            csv << @headers
            csv << duplicate_contact
            csv << @former_student
            csv << @student
            csv << @p_visit
          end
          @csv_file = fixture_file_upload("#{Rails.root}/spec/support/test.csv", "text/csv" )
          @account = Account.make(name: "testAccount")
          @new_import = Import.make(account: @account, headers: @headers)
          @new_import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
          @new_import.save
        end
        it "should add every contact" do
          expect{@new_import.process_CSV_without_delay}.to change{Contact.count}.by(4)
        end
        it "should add email as a custom attribute" do
          @new_import.process_CSV_without_delay
          con = Contact.where(kshema_id: "50013").first
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
      @account = Account.make(name: "testAccount")
      @new_import = Import.make(account: @account, headers: @headers)
      @new_import.attachment = Attachment.new(name: "CSV", file: @csv_file, account: @account)
      @new_import.save
      @new_import.process_CSV_without_delay
    end
    it "should return a CSV with all the failed errors" do
      csv = @new_import.failed_rows_to_csv
      csv.should_not be_nil
      # the failed person is Anoopa and her kshema_id is 50015
      csv.should include("Anoopa", "50015")
      # the failed row is 26
      csv.should include("26")
    end

  end

  describe "when import is destroyed" do
    let(:account){Account.make(name: "testAccount")}
    let(:attachment){Attachment.new(name: "CSV", file: @csv_file, account: account)}
    let(:import){Import.make(account: account, headers: @headers, attachment: attachment)}
    before do
      import.process_CSV_without_delay
      Contact.count.should == 3
    end
    it "destroys all created contacts" do
      expect{import.destroy}.to change{Contact.count}.by(-3)
    end
  end

  # Clean up
  after do
    File.delete("#{Rails.root}/spec/support/test.csv")
  end
end
