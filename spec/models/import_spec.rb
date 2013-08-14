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
                 "dwaynemac@gmail.com",	"6", "daniel.ferztand", "6", "h",
                 "/home/alex/workspace/Padma/public/persona/foto/50001/654da12b6a7905f62633eae7e76688c5.jpg",
                 "1983-05-21", "2005-05-13", "Instr. Método DeRose", "<p>algna observacion</p>", "true", "5",
                 "1428", "1", "", "", "2011-02-19 18:04:12 -0300", "", "", "", "", "", "", "", "", "",
                 "false", "", "", "", "", "", "", ""]
    @student =  ["50010", "", "Alex", "Falke", "", "4782 1495",	"15 5466 7896",	"afalkear@gmail.com", "6",
                 "lucia.gagliardini", "5", "h",
                 "/home/alex/workspace/Padma/public/persona/foto/50010/alex_web.jpg", "1983-03-11", "2004-12-01",
                 "Instructor del Método DeRose. Ingeniero informático.", "", "true", "5", "", "1",	"1667392", "",
                 "2013-01-11 14:03:29 -0300", "", "", "", "", "", "", "", "", "", "true", "", "", "", "", "", "", ""]
    @p_visit = ["50178", "", "Daniel", "Werber", "", "", "15 4437-6580", "werber@fibertel.com.ar", "1", "",	"3", "h",
                "","","", "BioquÃ­mico", "", "false", "", "", "1", "", "", "", "", "", "", "", "", "", "", "", "", "false", 
                "", "", "", "", "", "", ""]
    CSV.open("#{Rails.root}/spec/support/test.csv", "w") do |csv|
      csv << @headers
      csv << @former_student
      csv << @student
      csv << @p_visit
    end
    @csv_file = File.open("#{Rails.root}/spec/support/test.csv")
  end

  describe "create_contact" do
    context "with a correct CSV file" do
      before do
        account = Account.make
        @new_import = Import.new(account, @csv_file, @headers)
      end
      context "with all new contacts" do
        it "should create given contacts" do
          expect{@new_import.process_CSV}.to change{Contact.count}.by(3)
        end
        it "should have consistent data" do
          @new_import.process_CSV
          Contact.last.first_name.should == "Daniel"
          Contact.last.last_name.should == "Werber"
        end
        it "should have kshema_id" do
          @new_import.process_CSV
          Contact.last.kshema_id.should == "50178"
        end
        it "should distinguish between coefficients" do
          @new_import.process_CSV
          Contact.where(level: 5).count.should == 2
        end
      end
      context "with a contact that is already in the database" do
        before do
          @contact = Contact.make(first_name: "Dwayne", last_name: "Macgowan")
          @contact.contact_attributes << Telephone.make(value: "1540995071", category: "mobile")
          @contact.contact_attributes << Email.make(value: "dwaynemac@gmail.com", category: "personal")
          @contact.save
        end
        it "should not create the contact again" do
          expect{@new_import.process_CSV}.to change{Contact.count}.by(2)
        end
        it "should add the new contact attributes to the person" do
          @new_import.process_CSV
          @contact.identifications.last.value.should == "30 366 832"
        end
      end
    end
  end
end
